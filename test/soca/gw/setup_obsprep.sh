#!/bin/bash
set -ex

# working directory as set in cmake assumed to be ${PROJECT_BINARY_DIR}/test/soca/gw/obsprep
# which is the soca ctest's fake dmpdir
# Ensure project source directory is provided as argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <project_source_dir>"
    exit 1
fi

project_source_dir="$1"
testdatadir="${project_source_dir}/test/soca/testdata"
testdatadir_bufr="${project_source_dir}/build/gdas/test/testdata"

# run the g-w link script so that the config files can be found
(cd ${project_source_dir}/../../.. && ./link_workflow.sh)

# Clean up previous attempts
rm -rf gdas.20180414  gdas.20180415

# Define PDYs, cycs, and obstypes
PDYs=("20180414" "20180415")
cycs=("00" "06" "12" "18")
obstypes=("insitu" "sss" "adt" "icec" "sst")

# Copy marine obs (in situ BUFR and satellite retrieved netCDF files) to DMPDIR
for PDY in "${PDYs[@]}"; do
    PDYdir="gdas.${PDY}"
    for cyc in "${cycs[@]}"; do
        for obstype in "${obstypes[@]}"; do
            if [ $obstype != "insitu" ]; then
                fullsubdir="$PDYdir/$cyc/ocean/$obstype"
                mkdir -p "$fullsubdir"

                # Convert cdl files into nc for all cycles and obstypes
                indir="${testdatadir}/${fullsubdir}"
                for file in "$indir"/*.cdl; do
                    if [ -f "$file" ]; then
                        filename=$(basename -- "$file")
                        filename_noext="${filename%.cdl}"
                        ncgen -o "$fullsubdir/${filename_noext}.nc" "$file"
                    fi
                done
            else
                # Copy subsampled monthly in situ BUFR
                # Example filename: tesac.201804.dcom_subsampled are copied as
                # gdas.t00z.tesac.tm00.bufr_d (the original filename)
                for typ in bathy dbuoy dbuoyb mbuoy mbuoyb ships shipsu tesac trkob; do
                    if [ $(ls $testdatadir_bufr/${typ}.*subsampled 2>/dev/null | wc -l) -gt 0 ]; then
                        cp -p $testdatadir_bufr/${typ}.*subsampled \
                              $testdatadir_bufr/gdas.t${cyc}z.${typ}.tm00.bufr_d
                    fi
                done

                # TODO: SP to replace these with daily and monthly subsampled with proper dates 
                fullsubdir="$PDYdir/$cyc/atmos"
                mkdir -p "$fullsubdir"
                for file in "$testdatadir_bufr/*.bufr_d"; do
                    cp -p $file $fullsubdir
                done
            fi
        done
    done
done
