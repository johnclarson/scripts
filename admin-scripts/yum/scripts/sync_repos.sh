#!/bin/bash

: <<DOCUMENTATION

######################################################################
##                        Documentation                             ##
######################################################################
This script manages all sync, import and export of yum repos.
It will typically be run automatically but may be run ad hoc

DOCUMENTATION

## Define script constants
# Variables
date=$(date +%Y%m%d%H%M)
dtodate=$(date +%Y%m%d)
root_dir="${root_dir:-/data/repo_sync/process/}"
bucket_region="${bucket_region:-us-east-1}"
bucket_endpoint_url="${bucket_endpoint_url:-https://s3.us-east-1.amazonaws.com}"
comps_option=""
createrepo_workers="${createrepo_workers:-8}"
custom_src_dir="${custom_src_dir:-/data/repo_sync/sigma-locally-managed}"
dto_bucket="${dto_bucket:-s3://sigma-dto/}"
logfile="${date}.log"
reposync_args="${reposync_args:---downloadcomps --download-metadata --delete}"
reposync_file="${reposync_file:-/etc/sysconfig/reposync/reposync.conf}"
dto_repo_file="${dto_repo_file:-/etc/sysconfig/reposync/dto_repo.conf}"
dto_export_bucket_file="${dto_export_bucket_file:-/etc/sysconfig/reposync/dto_export_buckets.conf}"
s3_log_destination="${s3_log_destination:-s3://sigma-build/logs/sync_repos}"
source_yum_bucket="${source_yum_bucket:-s3://sigma-yum/}"
target_yum_bucket="${target_yum_bucket:-s3://sigma-yum/}"
target_yum_directory="${target_yum_directory:-/data/yum/yum}"
target_yum_snapshot_directory="${target_yum_snapshot_directory:-/data/yum/yum-snapshots}"

# Declare export DTO buckets for tarball copies
mapfile -t export_buckets < $dto_export_bucket_file

## Define the script usage method

show_help() {
    echo "Usage: $0 [option...] " 
    echo  
    echo "   Required Parameters:                                            "
    echo "                                                                   "
    echo "   -e|--export                   (boolean) Perform export function "
    echo "   -i|--import                   (boolean) Perform import function "
    echo "   -s|--sync                     (boolean) Perform sync function "
    echo "                                                                   "
    echo "   Optional Parameters:                                            "
    echo "                                                                   "
    echo "   -h|--help                         Help.                                "
    echo "   --repository                      [sync] single yum repository to sync "
    echo "   --sync2s3                         [sync] (boolean) Sync repos to configured S3 bucket "
    echo "   --target_yum_bucket               [sync and export] S3 bucket to send repos to "
    echo "   --target_yum_directory            [import] directory to send repos to "
    echo "   --target_yum_snapshot_directory   [import] directory to send snapshots to "
    echo "   --source_yum_bucket               [import] S3 bucket to get repos from "
    echo "   --s3_log_destination              [sync] location in S3 where logs are "
    echo "   --root_dir                        [generic] absolute path to execution home "
    echo "   --reposync_file                   [sync] config used for external repo sync "
    echo "   --dto_repo_file                   [sync] config used for repos designated for dto "
    echo "   --dto_export_bucket_file          [export] config used for designated export dto buckets "
    echo "   --reposync_destination            [sync] place where external repos are staged "
    echo "   --reposync_args                   [sync] arguments to apply to reposync cmd "
    echo "   --dto_bucket                      [im/export] S3 bucket where dto import and export content is "
    echo "   --bucket_region                   [im/export] AWS region where S3 bucket is "
    echo "   --bucket_endpoint_url             [im/export] AWS S3 endpoint "
    echo "   --createrepo_workers              [sync] number of threads for createrepo commands "
    echo "   --custom_src_dir                  [export] place where locally managed yum repos are "
    exit 1
}
 
######################################################################
## Process command line arguments
##

## Grab options
while :; do
     case $1 in
         -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
             sed --silent -e '/DOCUMENTATION$/,/^DOCUMENTATION$/p' "$0" | sed -e '/DOCUMENTATION$/d' | sed -e 's/^/  /'
             show_help
             exit
             ;;
         -e|--export)   # Perform export function.
             export="true"
             ;;
         -i|--import)   # Perform import function.
             import="true"
             ;;
         -s|--sync)   # Perform sync function.
             sync="true"
             ;;
         --sync2s3) # Set a boolean for syncing to S3.
          sync2s3="true"
             ;;
         --bucket_endpoint_url)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 bucket_endpoint_url=$2
                 shift
             else
                 printf 'ERROR: "--bucket_endpoint_url" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --bucket_endpoint_url=?*)
             bucket_endpoint_url=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --bucket_endpoint_url=)         # Handle the case of an empty --bucket_endpoint_url=
             printf 'ERROR: "--bucket_endpoint_url" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --bucket_region)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 bucket_region=$2
                 shift
             else
                 printf 'ERROR: "--bucket_region" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --bucket_region=?*)
             bucket_region=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --bucket_region=)         # Handle the case of an empty --bucket_region=
             printf 'ERROR: "--bucket_region" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --createrepo_workers)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 createrepo_workers=$2
                 shift
             else
                 printf 'ERROR: "--createrepo_workers" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --createrepo_workers=?*)
             createrepo_workers=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --createrepo_workers=)         # Handle the case of an empty --createrepo_workers=
             printf 'ERROR: "--createrepo_workers" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --custom_src_dir)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 custom_src_dir=$2
                 shift
             else
                 printf 'ERROR: "--custom_src_dir" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --custom_src_dir=?*)
             custom_src_dir=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --custom_src_dir=)         # Handle the case of an empty --custom_src_dir=
             printf 'ERROR: "--custom_src_dir" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --dto_bucket)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 dto_bucket=$2
                 shift
             else
                 printf 'ERROR: "--dto_bucket" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --dto_bucket=?*)
             dto_bucket=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --dto_bucket=)         # Handle the case of an empty --dto_bucket=
             printf 'ERROR: "--dto_bucket" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --repository)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 repository=$2
                 shift
             else
                 printf 'ERROR: "--repository" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --repository=?*)
             repository=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --repository=)         # Handle the case of an empty --repository=
             printf 'ERROR: "--repository" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --reposync_args)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 reposync_args=$2
                 shift
             else
                 printf 'ERROR: "--reposync_args" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --reposync_args=?*)
             reposync_args=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --reposync_args=)         # Handle the case of an empty --reposync_args=
             printf 'ERROR: "--reposync_args" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --reposync_destination)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 reposync_destination=$2
                 shift
             else
                 printf 'ERROR: "--reposync_destination" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --reposync_destination=?*)
             reposync_destination=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --reposync_destination=)         # Handle the case of an empty --reposync_destination=
             printf 'ERROR: "--reposync_destination" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --reposync_file)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 reposync_file=$2
                 shift
             else
                 printf 'ERROR: "--reposync_file" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --reposync_file=?*)
             reposync_file=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --reposync_file=)         # Handle the case of an empty --reposync_file=
             printf 'ERROR: "--reposync_file" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --dto_repo_file)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 dto_repo_file=$2
                 shift
             else
                 printf 'ERROR: "--dto_repo_file" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --dto_repo_file=?*)
             dto_repo_file=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --dto_repo_file=)         # Handle the case of an empty --dto_repo_file=
             printf 'ERROR: "--dto_repo_file" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --dto_export_bucket_file)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 dto_export_bucket_file=$2
                 shift
             else
                 printf 'ERROR: "--dto_export_bucket_file" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --dto_export_bucket_file=?*)
             dto_export_bucket_file=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --dto_export_bucket_file=)         # Handle the case of an empty --dto_export_bucket_file=
             printf 'ERROR: "--dto_export_bucket_file" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --root_dir)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 root_dir=$2
                 shift
             else
                 printf 'ERROR: "--root_dir" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --root_dir=?*)
             root_dir=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --root_dir=)         # Handle the case of an empty --root_dir=
             printf 'ERROR: "--root_dir" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --s3_log_destination)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 s3_log_destination=$2
                 shift
             else
                 printf 'ERROR: "--s3_log_destination" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --s3_log_destination=?*)
             s3_log_destination=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --s3_log_destination=)         # Handle the case of an empty --s3_log_destination=
             printf 'ERROR: "--s3_log_destination" requires a non-empty option argument.\n' >&2
             exit 1
             ;; 
         --source_yum_bucket)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 source_yum_bucket=$2
                 shift
             else
                 printf 'ERROR: "--source_yum_bucket" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --source_yum_bucket=?*)
             source_yum_bucket=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --source_yum_bucket=)         # Handle the case of an empty --source_yum_bucket=
             printf 'ERROR: "--source_yum_bucket" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --target_yum_bucket)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 target_yum_bucket=$2
                 shift
             else
                 printf 'ERROR: "--target_yum_bucket" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --target_yum_bucket=?*)
             target_yum_bucket=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --target_yum_bucket=)         # Handle the case of an empty --target_yum_bucket=
             printf 'ERROR: "--target_yum_bucket" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --target_yum_directory)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 target_yum_directory=$2
                 shift
             else
                 printf 'ERROR: "--target_yum_directory" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --target_yum_directory=?*)
             target_yum_directory=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --target_yum_directory=)         # Handle the case of an empty --target_yum_directory=
             printf 'ERROR: "--target_yum_directory" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --target_yum_snapshot_directory)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 target_yum_snapshot_directory=$2
                 shift
             else
                 printf 'ERROR: "--target_yum_snapshot_directory" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --target_yum_snapshot_directory=?*)
             target_yum_snapshot_directory=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --target_yum_snapshot_directory=)         # Handle the case of an empty --target_yum_snapshot_directory=
             printf 'ERROR: "--target_yum_snapshot_directory" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --)              # End of all options.
             shift
             break
             ;;
         -?*)
             printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
             ;;
         *)               # Default case: If no more options then break out of the loop.
             break
     esac
 
     shift
done

# Check for AWS CLI
if [ ! -f /bin/aws ]; then
    echo "AWS CLI is required. Install awscli..."
    exit 1
fi

# Process directories based on root 
import_dir="${root_dir}import"
input_dir="${root_dir}versions/$date"
add_dir="${input_dir}/add"
current_repo_dir="${root_dir}current"
dto_input_file="${input_dir}/dto-diff.$date"
previous_dir=$(ls ${root_dir}versions | tail -n 1)
reposync_destination="${reposync_destination:-${root_dir}sync}"
rm_file="${input_dir}/remove"
aws_options="--region $bucket_region --endpoint-url=$bucket_endpoint_url"

sync_repo ( ) {
    repo=$1
    echo -e "################################################\n## ${repo}\n##" | tee -a /tmp/$logfile
    echo -e "## Syncing repo [${repo}]..." | tee -a /tmp/$logfile
    while [ -f /var/run/yum.pid ]; do
        sleep 5
    done
    /bin/yum clean all
    reposync_command="/bin/reposync --config=${reposync_file} --repoid=${repo} ${reposync_args} --download_path=${reposync_destination}"
    echo -e "##\tCommand: ${reposync_command}" | tee -a /tmp/$logfile
    ${reposync_command} | tee -a /tmp/$logfile
    echo -e "##" | tee -a /tmp/$logfile
    echo -e "## Creating repodata for [${repo}]..." | tee -a /tmp/$logfile
    groupfile="${reposync_destination}/${repo}/comps.xml"
    if [ -f "${groupfile}" ]; then
        comps_option="--groupfile=${groupfile}"
    fi
    createrepo_command="/bin/createrepo --workers=${createrepo_workers} ${comps_option} ${reposync_destination}/${repo}/"
    echo -e "##\tCommand: ${createrepo_command}" | tee -a /tmp/$logfile
    ${createrepo_command} | tee -a /tmp/$logfile

}

sync_locally_managed_repos ( ) {
    for repo in $( ls  ${custom_src_dir} ); do 
        createrepo_command="/bin/createrepo --workers=${createrepo_workers} ${comps_option} ${custom_src_dir}/${repo}/"
        echo -e "##\tCommand: ${createrepo_command}" | tee -a /tmp/$logfile
        ${createrepo_command} | tee -a /tmp/$logfile
        /bin/aws s3 $aws_options sync ${custom_src_dir}/${repo}/ ${target_yum_bucket}${repo}/ --delete | tee -a /tmp/$logfile
    done
        
}

sync_s3 ( ) {
    for repo in $( ls  ${reposync_destination} ); do
        /bin/aws s3 $aws_options sync ${reposync_destination}/${repo}/ ${target_yum_bucket}${repo} --delete  | tee -a /tmp/$logfile
    done
}

process_logfile ( ) {
    echo "Processing logfile..." | tee -a /tmp/$logfile
    gzip /tmp/$logfile 
    /bin/aws s3 $aws_options cp /tmp/$logfile.gz $s3_log_destination/$logfile.gz
}

sync_individual_repo ( ) {
    if [ $repository ]; then
        target_yum_bucket="${target_yum_bucket}/$repository/"
        sync_repo $repository | tee -a /tmp/$logfile
        if [ $sync2s3 ]; then
            reposync_destination="$reposync_destination/$repository"
            sync_s3 
        fi
    fi
}

sync_all_repos ( ) {
    if [ ! $repository ]; then
        for repo in $( cat ${reposync_file} | grep "^\s*\[sigma" | sed -e "s/^\s*\[\(.*\)\].*/\1/" ); do
            if [ ! -d "${reposync_destination}//${repo}" ]; then
                mkdir "${reposync_destination}//${repo}"
            fi
            groupfile=
            if [ -d "${reposync_destination}//${repo}/repodata" ]; then
                rm -rf ${reposync_destination}//${repo}/repodata
            fi
            sync_repo $repo  
        done

        ## Sync to AWS S3 and copy log file up
        if [ $sync2s3 ]; then
            sync_s3 
        fi
    fi
}

export_sync ( ) {
    # Sync previous version repos to new version
    mkdir -p ${input_dir}
    echo "Syncing ${root_dir}versions/${previous_dir}/dto to ${input_dir}" | tee -a /tmp/$logfile
    rsync -aq  ${root_dir}versions/${previous_dir}/dto ${input_dir}
}

create_diff ( ) {
    # Create a diff of previous and current versions of $1 RPMs for processing
    echo "creating $2 for processing" | tee -a /tmp/$logfile
    diff -B <(cd ${root_dir}versions/${previous_dir} && find -L $1 -name "*.rpm" | sort) <(cd ${input_dir} && find -L $1 -name "*.rpm" | sort) > $2
}


process_diff ( ) {
    # Process diff file and set up add and remove content for $1 RPMs
    if [ ! -s $2 ]; then
        echo "There is no difference in ${previous_dir}/${1} and ${date}/${1}. Skipping processing of ${1}" | tee -a /tmp/$logfile
    else
        echo "processing ${2}..." | tee -a /tmp/$logfile
        mkdir -p $add_dir

        while read line;
        do
            if [[ $line =~ ">" ]]; then
                local_filepath=${line:2}
                filepath=${line:$3}
                dir=$(dirname $filepath)
                rpm=$(basename $filepath)
                if [ ! -d "${add_dir}/${dir}" ]; then
                    mkdir -p ${add_dir}/${dir}
                fi
                if [ ! -f "${add_dir}/${dir}/${rpm}" ]; then
                    cp ${input_dir}/$local_filepath ${add_dir}/${dir}
                fi
            elif [[ $line =~ "<" ]]; then
                filepath=${line:$3}
                rpm=$(basename $filepath)
                echo $filepath >> $rm_file
            fi

        done < "$2"
        # Pack up tarball for $1 RPMs for this version
        echo "packing ${1} tarball for export..." | tee -a /tmp/$logfile
        tar czf ${input_dir}/${1}_repos.${date}.tgz -C ${root_dir}versions/${date} add remove 2> /dev/null
        # Process dto location target
        if [ $1 == "dto" ]; then
            bucket=$dto_bucket
        elif [ $1 == "custom" ]; then
            bucket=$custom_bucket
        else
            echo "Need a type to process. Either dto or custom."
            exit
        fi
        aws s3 ls $aws_options ${bucket} | grep ${dtodate} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            x=1
            while [ ! $newdir ]
            do
                aws s3 ls $aws_options ${bucket} | grep ${dtodate}.${x} > /dev/null 2>&1
                if [ $? -eq 1 ]; then
                    newdir=${dtodate}.${x}
                else
                    x=$[$x+1]
                fi
            done
        else
            newdir=${dtodate}.1
        fi
        for ebucket in "${export_buckets[@]}"
        do
            echo "Copying ${input_dir}/${1}_repos.${date}.tgz to ${ebucket}/${newdir}/${1}_repos.${date}.tgz" | tee -a /tmp/$logfile
            aws s3 cp $aws_options ${input_dir}/${1}_repos.${date}.tgz ${ebucket}/${newdir}/${1}_repos.${date}.tgz 

        done
        rm -f ${input_dir}/${1}_repos.${date}.tgz 

    fi
        
}

sync_dto ( ) {
    # Sync DTO repos from S3 to new version
    echo "Syncing DTO repos from S3..." | tee -a /tmp/$logfile 
    for repo in $( cat ${dto_repo_file} );
    do
        echo "Syncing ${repo}..." | tee -a /tmp/$logfile
        echo "aws s3 sync $aws_options ${source_yum_bucket}${repo}/ ${input_dir}/dto/${repo} --delete" | tee -a /tmp/$logfile 
        aws s3 sync $aws_options ${source_yum_bucket}${repo}/ ${input_dir}/dto/${repo} --delete 
    done
}

import ( ) {
    bucket=$dto_bucket
    echo "DTO bucket is ${bucket}" | tee -a /tmp/$logfile
    mkdir -p ${import_dir}
    echo "Searching for yum tarballs in ${bucket}..." | tee -a /tmp/$logfile
    aws s3 sync $aws_options ${bucket} ${import_dir}  --exclude "*" --include "*dto*tgz" --delete | tee -a /tmp/$logfile
    dircount=$(find ${import_dir} -maxdepth 1 -type d | wc -l)   
    if [ $dircount -gt "1" ]; then
        echo "Processing yum content..." | tee -a /tmp/$logfile
        for idir in ${import_dir}/*;
        do
            process=true
            tarball=$(ls ${idir} | grep dto_repos)
            echo "Extracting yum content from ${tarball}..." | tee -a /tmp/$logfile
            tarball_date=$(echo $tarball | cut -f2 -d.)
            tar xvzf ${idir}/${tarball} -C ${idir} | tee -a /tmp/$logfile
            if [ -d "${idir}/remove" ]; then
                echo "Performing RPM removals..." | tee -a /tmp/$logfile
                while read line;
                do
                    echo "rm -f ${target_yum_directory}/${line}" | tee -a /tmp/$logfile
                    rm -f ${target_yum_directory}/${line}
                done < ${idir}/remove
            fi
            if [ -d "${idir}/add" ]; then
                echo "Adding new RPMS..." | tee -a /tmp/$logfile
                rsync -av ${idir}/add/ ${target_yum_directory} | tee -a /tmp/$logfile
            fi
            echo "Syncing local yum data to S3..." | tee -a /tmp/$logfile
            for subdir in $(ls ${target_yum_directory});
            do
                echo "Creating repodata for $subdir..." | tee -a /tmp/$logfile
                createrepo ${target_yum_directory}/${subdir} | tee -a /tmp/$logfile
                aws s3 sync $aws_options ${target_yum_directory}/${subdir} ${target_yum_bucket}${subdir} --delete | tee -a /tmp/$logfile 
            done
            echo "Performing time machine snapshot called ${tarball_date}..." | tee -a /tmp/$logfile
            /usr/bin/time-machine -v -s ${target_yum_directory}/ -d ${target_yum_snapshot_directory}/ -C ${tarball_date} | tee -a /tmp/$logfile
            rc=$?
            if [ "${rc}" != "0" ]; then
                echo "ERROR: TimeMachine snapshot failed (COMMAND: /usr/bin/time-machine.sh -s ${target_yum_directory}/ -d ${target_yum_snapshot_directory}/ -C ${tarball_date} -v)! Please do something about that!" | tee -a /tmp/$logfile
                exit 1
            fi
            echo "Syncing ${tarball_date} to ${target_yum_bucket}snapshots/${tarball_date}..." | tee -a /tmp/$logfile 
            aws s3 sync $aws_options ${target_yum_snapshot_directory}/${tarball_date} ${target_yum_bucket}snapshots/${tarball_date} --quiet 
            folder=$(basename ${idir})
            echo "Renaming source tarball in S3..." | tee -a /tmp/$logfile
            aws s3 mv $aws_options ${bucket}${folder}/${tarball} ${bucket}${folder}/processed_on_${date}.repos.${tarball_date}.tgz | tee -a /tmp/$logfile
            rm -rf ${idir}
        done
    fi
    if [ ! $process ]; then  
        echo "No processing required this run..."  | tee -a /tmp/$logfile
    fi
}


clean_up ( ) {
    # Clean up 
    echo "Removing previous content to save space..." | tee -a /tmp/$logfile 
    echo "rm -rf ${input_dir}/add" | tee -a /tmp/$logfile
    rm -rf ${input_dir}/add
    echo "rm -rf ${input_dir}/remove" | tee -a /tmp/$logfile
    rm -rf ${input_dir}/remove
    echo "rm -rf ${input_dir}/*diff*" | tee -a /tmp/$logfile
    rm -rf ${input_dir}/*diff*
    echo "rm -rf ${input_dir}/*.tgz" | tee -a /tmp/$logfile
    rm -rf ${input_dir}/*.tgz
    echo "rm -rf ${root_dir}versions/${previous_dir}" | tee -a /tmp/$logfile 
    rm -rf ${root_dir}versions/${previous_dir} 
}

if [ $export ]; then
    export_sync
    sync_locally_managed_repos
    sync_dto  
    create_diff dto $dto_input_file 
    process_diff dto $dto_input_file 6 
    clean_up  
    process_logfile
elif [ $import ]; then
    import 
    process_logfile
elif [ $sync ]; then
    sync_individual_repo
    sync_all_repos
    process_logfile
else
    echo "Please supply a function (import, export, or sync)."    
fi
