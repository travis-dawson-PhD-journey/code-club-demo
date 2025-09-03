#!/usr/bin/env python3
import argparse
import glob
import xarray as xr
import traceback

# -----------------------------------------------------------------------------
# process_date.py
# Purpose:
#   - Access ~161 GRIB2 files for a given forecast date (00Z cycle, hours 0–240)
#   - Combine them into a single xarray Dataset
#   - Apply preprocessing:
#       * Subset latitude/longitude region
#       * Ensure latitudes are ordered south → north
#       * Drop unused or redundant variables
#       * Flatten sequence variables (convert 4D → multiple 3D fields)
#   - Save the processed dataset as Zarr (chunked in time, e.g. 0–120 and 123–240)
#
# Example usage:
#   python process_date.py \
#       --date 20210414 \
#       --input-root /scratch/$USER/gfs_sample \
#       --output-root /scratch/$USER/zarr_store
# * Used within `grib_2_zarr_single.sh` and `grib_2_zarr_multi.sh` 
# -----------------------------------------------------------------------------

# Vars that arrive as 4D (step, orderedSequenceData, lat, lon)
# → flattened into multiple 3D fields var_0, var_1, ...
SEQUENCE_VARS = ("shts", "mpts", "swdir") 

def preprocess_slice_flip(ds: xr.Dataset) -> xr.Dataset:
    """Ensure ascending latitude order, then trim to region.

    This function flips the latitude dimension if necessary so that it
    runs from south to north (ascending order). It then subsets the
    dataset to a fixed spatial window:

      * Latitude: -70 → 0
      * Longitude: -60 → 135

    Args:
        ds (xr.Dataset): Dataset from a single GRIB2 file.

    Returns:
        xr.Dataset: The dataset trimmed to the specified lat/lon region,
        with latitude in ascending order.
    """
    ds = ds.isel(latitude=slice(None, None, -1))  # Order latitude from South to North (works with matplitlob.pyplot visualization)

    # Slice the gridded region based on coordinate values
    ds = ds.sel(latitude=slice(-70, 0), longitude=slice(-60, 135))
    return ds

def flatten_sequence_vars(ds: xr.Dataset, vars_to_flatten=SEQUENCE_VARS) -> xr.Dataset:
    """Flatten sequence-type variables by expanding the `orderedSequenceData` dimension.

    Some GRIB2 variables (e.g., swdir, mpts, shts) store multiple values
    along an artificial dimension called `orderedSequenceData`. This function
    splits such variables into multiple 3D variables with suffixes `_0`, `_1`,
    …, removing the original sequence variable and dropping the
    `orderedSequenceData` dimension if it becomes unused.

    Args:
        ds (xr.Dataset): Input dataset, possibly containing variables with an
            `orderedSequenceData` dimension.
        vars_to_flatten (Iterable[str], optional): List or tuple of variable
            names expected to use the sequence dimension. Defaults to
            `SEQUENCE_VARS`.

    Returns:
        xr.Dataset: A dataset where:
            * Each sequence variable is replaced by multiple 3D variables
              (dims: step, lat, lon).
            * The `orderedSequenceData` dimension is dropped if no variables use it.
    """
    ordered_seq_dim = "orderedSequenceData"  # String is used multiple times -> Create a variable
    if ordered_seq_dim not in ds.dims:  # No orderedSequenceData field found
        return ds

    out = ds
    n = out.sizes[ordered_seq_dim]  # Get the size of the orderedSequenceData dim (3)

    for var in vars_to_flatten:  # Loop through variables to flatten
        if var in out and ordered_seq_dim in out[var].dims:  # Variable is present and uses orderedSequenceData
            for i in range(n):  # Iterate through dimension length (3)
                out[f"{var}_{i}"] = out[var].isel(orderedSequenceData=i)   # Create new filed var_i equal to the orderedSequenceData=i
            out = out.drop_vars(var)  # Remove the variable

    if ordered_seq_dim in out.dims:  # Still a dimension
        still_uses = any(ordered_seq_dim in out[v].dims for v in out.data_vars)  # Any variables still use the dim
        if not still_uses:  # No variable uses it
            out = out.drop_dims(ordered_seq_dim)  # Drop dimension
    if ordered_seq_dim in out.variables:  # Removes it if its a coordinate
        out = out.drop_vars(ordered_seq_dim)

    return out

def process_one_date(
    date: str,
    input_root: str,
    output_root: str,
    file_pattern: str = "gfs.{date}/00/wave/gridded/*.grib2",
    chunk_step: int = 81,
    zarr_format: int = 2
):
    """Combine, preprocess, and write one forecast date to Zarr.

    Finds all GRIB2 files for a single forecast date, opens them as a single
    xarray Dataset (concatenated along `step`), applies spatial trimming and
    latitude orientation fixes, removes redundant variables, flattens
    sequence-type variables, and writes the result to a Zarr format.

    Args:
      date (str): Forecast date in `YYYYMMDD` format (e.g., `"20210414"`).
      input_root (str): Root directory containing GRIB2 files. The function
        searches under `{input_root}/{file_pattern}`. which uses date variable.
      output_root (str): Directory where the Zarr output will be written as
        `{output_root}/{date}.zarr`.
      file_pattern (str, optional): Glob pattern (relative to `input_root`)
        that locates the date's GRIB2 files. Defaults to
        `"gfs.{date}/00/wave/gridded/*.grib2"`.
      chunk_step (int, optional): Dask chunk size along the `step` dimension.
        Defaults to `81` (roughly splits 0-240h into two large time chunks:
        0-120 and 123-240).
      zarr_format (int, optional): Zarr format version. Only `2` is supported
        here. Defaults to `2`.

    Raises:
      FileNotFoundError: If no GRIB2 files are found for the given ``date`` and
        `file_pattern`.

    Returns:
      None: Writes a Zarr store to disk and prints a completion message.
    """
    # Locate input files for this date
    pattern = f"{input_root}/{file_pattern.format(date=date)}"
    files = sorted(glob.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No GRIB2 files for date={date} with pattern={pattern}")

    # Open and concatenate along forecast step; apply spatial trim + lat flip per file
    ds = xr.open_mfdataset(
        files,
        engine="cfgrib",
        backend_kwargs={"indexpath": ""},
        combine="nested",
        concat_dim="step",
        preprocess=preprocess_slice_flip,  # Preprocessing applied here
        parallel=False,  # IO bound so parallel does not help as much here
        chunks={"step": chunk_step},
        compat="override",  # Forecast is consistent, minimal safety checks
        coords="minimal",
        data_vars="minimal",
        decode_timedelta=False
    )

    # Drop unused variables
    for v in ("surface", "valid_time"):
        if v in ds:
            ds = ds.drop_vars(v)

    # Flatten sequence-type variables (e.g., swdir → swdir_0, swdir_1, …)
    ds = flatten_sequence_vars(ds, SEQUENCE_VARS)

    # Write to consolidated Zarr store
    # This can take a little bit of time if run locally (< 5 min)
    out_path = f"{output_root}/{date}.zarr"
    ds = ds.chunk({"step": 81})
    ds.to_zarr(out_path, mode="w", consolidated=True, zarr_format=zarr_format)
    print(f"[{date}] wrote {out_path}", flush=True)

def main():
    parser = argparse.ArgumentParser(description="Process one forecast date into Zarr")
    parser.add_argument("--date", required=True, help="Date key, e.g. 20240115")
    parser.add_argument("--input-root", required=True, help="Directory containing GRIB2 files")
    parser.add_argument("--output-root", required=True, help="Directory to write Zarr outputs")
    parser.add_argument("--file-pattern", default="gfs.{date}/00/wave/gridded/*.grib2")
    parser.add_argument("--chunk-step", type=int, default=81)
    parser.add_argument("--zarr-format", type=int, default=2, choices=[2])
    args = parser.parse_args()

    try:
        process_one_date(
            date=args.date,
            input_root=args.input_root,
            output_root=args.output_root,
            file_pattern=args.file_pattern,
            chunk_step=args.chunk_step,
            zarr_format=args.zarr_format,
        )
        print("=== Finished successfully ===", flush=True)
    except Exception as e:
        traceback.print_exc()
        print("!!! ERROR !!!", flush=True)

if __name__ == "__main__":
    main()
