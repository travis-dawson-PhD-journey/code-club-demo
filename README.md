# code-club-demo
Efficient Preprocessing of NOAA GFS Wave Forecasts with Zarr and HPC

## Introduction
My name is Travis Dawson, I'm a PhD student at the University of Western Australia, based at the Indian Ocean Marine Research Centre. 
My research looks at how we can use deep learning to improve ocean wave forecasts (i.e. Post-processing) at specific sites. These forecasts are critical for industries that rely heavily on accurate forecasts, such as floating wind turbines, FLNG platforms, and other offshore assets. 

I'm still in the early stages of my PhD, and have been working on how to pre-process and wrangle nearly 4TB of forecast data (about 806,825 files) for an experimental setup, in an efficient and practical way.  It's a problem of both scale and structure: a huge data volume, and significant number of small files. 

In Thursday's talk, I'll walk you through the approach I've been developing, which brings together two key tools. First, the massively parallel capability of the Setonix  HPC system, which allows for large-scale downloads and processing. Second, the Zarr file format, which supports my experimental setup by letting me pull only the specific variables I need, such as one out of 19, from object storage into the scratch space (high-speed local storage), instead of moving entire datasets unnecessarily. 

## Data
The NOAA Global Forecast System (GFS) dataset is available [here](https://aws.amazon.com/marketplace/pp/prodview-hok7o2o24ktfi#resources)

If you want to try follow the below demo on your local machine, please download `gfs.20210101.zip` and `zarr_store.zip` into the project root directory. Please note these files are around 2.0 GB in total so may take a little time to download. 

The download link is here: [https://drive.google.com/drive/folders/1dWz98v_yn1C2H1Qh3NIYlFqBwJStx_10?usp=sharing](https://drive.google.com/drive/folders/1dWz98v_yn1C2H1Qh3NIYlFqBwJStx_10?usp=sharing)

## Environment Setup
1. Create the virtual environment
```bash
python3 -m venv .venv
```
2. Activate virtual environment
- Linux/ Mac: `source .venv/bin/activate`
- Windows: `.\venv\Scripts\Activate.ps1`

3. Install required packages
```bash
pip install -r dataProcessing/requirements.txt
```

## Data Download and Processing Demo
For this demo we’ll use a pre-packaged sample forecast (2022-01-01) provided in gfs.20220101.zip. It can be completed on your local device, and will provide insight into how this demo can then be made massively parallel from a single date. 

1. Create a target directory (this ensures the path exists):
```bash
mkdir -p gfs_sample/gfs.20220101
```

2. Extract the zip archive into that directory:
```bash
unzip gfs.20220101.zip -d gfs_sample/gfs.20220101
```

After running the commands you should see the following file structure (run `tree` from the `gfs_sample` directory) with 161 `grib2` files.
```bash
.
└── gfs.20220101
    └── 00
        └── wave
            └── gridded
                ├── gfswave.t00z.global.0p25.f000.grib2
                ├── gfswave.t00z.global.0p25.f001.grib2
                .
                ├── gfswave.t00z.global.0p25.f240.grib2

```

3. Run the process_date.py locally on the extracted data (`.zarr_store` will be created for you).
Alternatively, you can extract the zipped output using `unzip zarr_store.zip -d ./zarr_store`.

```bash
python3 -u dataProcessing/process_date.py \
  --date 20220101 \
  --input-root "./gfs_sample" \
  --output-root "./zarr_store"
```
After running the following will display indicating successful processing:
```bash
[20220101] wrote ./zarr_store/20220101.zarr
=== Finished successfully ===
```

The resulting sample `Zarr` directory will have the following structure (running tree from `zarr_store`)
```bash
.
└── 20220101.zarr
    ├── dirpw
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── latitude
    │   └── 0
    ├── longitude
    │   └── 0
    ├── mpts_0
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── mpts_1
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── mpts_2
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── mpww
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── perpw
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── shts_0
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── shts_1
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── shts_2
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── shww
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── step
    │   └── 0
    ├── swdir_0
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── swdir_1
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── swdir_2
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── swh
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── time
    │   └── 0
    ├── u
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── v
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── wdir
    │   ├── 0.0.0
    │   └── 1.0.0
    ├── ws
    │   ├── 0.0.0
    │   └── 1.0.0
    └── wvdir
        ├── 0.0.0
        └── 1.0.0
```

Because the NOAA GFS wave data is stored in a date-separated directory structure (e.g., gfs.YYYYMMDD/...), each forecast date is an independent unit of work. This makes the workflow embarrassingly parallel: one job = one day of GRIB2 files → one Zarr output. On HPC or cloud systems, hundreds of such jobs can run side-by-side with no dependencies, turning what looks like a massive dataset into a massively parallel workload.

⚠️ Note: When scaling up, be aware of I/O bottlenecks and remote access limits such as the GFS AWS bucket. 

## Zarr Format for Experimental Setup (Why we went through all that effort)
My experimental setup requires adjusting which forecast variables are used (there are 19 in total). The `.zarr` files are stored in Setonix object storage (Acacia), but for performance when training deep learning models, I would stage them into scratch to utilize the high-speed local storage capability. 

Because Zarr stores each variable in its own directory and chunks data along the step dimension, I don’t need to move the entire dataset. Instead, I can use rclone filters to copy just the variables and time slices I care about. For example, I might select only the first 5 forecast days (hours 0–120) for three variables:
- u → u-component of wind
- v → v-component of wind
- swh → significant wave height

The full set of available variables is:
```python
['ws', 'wdir', 'u', 'v', 'swh', 'perpw', 'dirpw', 'shww', 'shts_0', 'shts_1', 'shts_2', 'mpww', 'mpts_0', 'mpts_1', 'mpts_2', 'wvdir', 'swdir_0', 'swdir_1', 'swdir_2']
```

With a filter file (sample.filters), I can specify that rclone keeps only the metadata, coordinates, the selected variables, and specific chunks (e.g., 0.0.0 for the first 5 days), while excluding everything else:

```bash
 rclone copy ./zarr_store/ ./zarr_partial/ --transfers=8 --checkers=16 --progress --filter-from=./sample.filters
```

Filter specification below:
```bash
+ *.zarr/.zgroup
+ *.zarr/.zattrs
+ *.zarr/.zmetadata
+ *.zarr/longitude/**
+ *.zarr/latitude/**
+ *.zarr/time/**
+ *.zarr/swh/
+ *.zarr/swh/.zarray
+ *.zarr/swh/.zattrs
+ *.zarr/swh/0.0.0
+ *.zarr/u/
+ *.zarr/u/.zarray
+ *.zarr/u/.zattrs
+ *.zarr/u/0.0.0
+ *.zarr/v/
+ *.zarr/v/.zarray
+ *.zarr/v/.zattrs
+ *.zarr/v/0.0.0
- **
```
This way, the transfer is minimal: only the metadata, coordinates, u, v, swh, and the first five days of forecast data are moved from Acacia to scratch.

---

Look into `zarr_experimental_benefits.ipynb` to open the partial file. You will find only the metadata, and selected variables available for use. 