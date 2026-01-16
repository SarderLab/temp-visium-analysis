"""Implementing cell composition deconvolution
"""
import os
from ctk_cli import CLIArgumentParser
import girder_client

import subprocess


ORGAN_REF_KEY = {
    "Azimuth Adipose Reference": "adiposeref",
    "Azimuth Bone Marrow Reference": "bonemarrowref",
    "Azimuth Fetus Reference": "fetusref",
    "Azimuth Heart Reference": "heartref",
    "Azimuth Human Cortex Reference": "humancortexref",
    "Azimuth Kidney Reference": "kidneyref",
    "KPMP Atlas Kidney": "kidneykpmp",
    "Azimuth Lung Reference": "lungref",
    "Azimuth Pancreas Reference": "pancreasref",
    "Azimuth Mouse Cortex Reference": "mousecortexref",
    "Azimuth PBMC Reference": "pbmcref",
    "Azimuth Tonsil Reference": "tonsilref",
}

INTEGRATION_DATA_KEYS = {
    'adiposeref': ['celltype.l1','celltype.l2'],
    'bonemarrowref': ['celltype.l1','celltype.l2'],
    'fetusref': ['annotation.l2','annotation.l1'],
    'heartref': ['celltype.l1','celltype.l2'],
    'humancortexref': ['class','subclass','cluster','cross-species cluster'],
    'kidneyref': ['annotation.l1','annotation.l2','annotation.l3'],
    'kidneykpmp': ['subclass.l2','subclass.l1'],
    'lungref': ['annotation.l1','annotation.l2'],
    'pancreasref': ['celltype.l1','celltype.l2'],
    'mousecortexref': ['class','subclass','cluster','cross-species cluster'],
    'pbmcref': ['celltype.l1','celltype.l2','celltype.l3'],
    'tonsilref': ['celltype.l1','celltype.l2']
}


def main(args):

    gc = girder_client.GirderClient(
        apiUrl = args.girderApiUrl
    )
    gc.setToken(args.girderToken)

    print('Input arguments:')
    for a in vars(args):
        print(f'{a}: {getattr(args,a)}')

    if not args.organ == 'Not Listed':
        # print contents of current working directory, see if files were copied over
        print('Contents of working directory')
        print(os.listdir(os.getcwd()+'/'))
        # Getting file information from girder
        image_file_info = gc.get(f'/file/{args.input_image}')
        query_file_info = gc.get(f'/file/{args.counts_file}')
        reference_info = gc.get(f'/file/{args.reference}')

        # Downloading counts file to cwd
        gc.downloadFile(
            args.counts_file,
            path = f'{os.getcwd()}/{query_file_info["name"]}'
        )

        if args.organ == 'KPMP Atlas Kidney':
            print('Using KPMP Atlas Kidney reference, ensure reference file is provided')
            if not args.reference:
                raise ValueError('Reference file must be provided for KPMP Atlas Kidney organ option')
            # Downloading reference file to cwd
            gc.downloadFile(
                args.reference,
                path = f'{os.getcwd()}/{reference_info["name"]}'
            )

        print('Updated contents of directory')
        print(os.listdir(os.getcwd()+'/'))

        print(f'Running Label Transfer for: {args.organ}')
        subprocess.call(['Rscript', '../scripts/label_transfer.r', '"'+query_file_info['name']+'"', '"'+ORGAN_REF_KEY[args.organ]+'"', '"'+reference_info['name']+'"'])

        print(os.listdir(os.getcwd()+'/'))
        print(f'Uploading file to {query_file_info["itemId"]}')
        # Posting integration results to item
        file_ext = query_file_info['name'].split('.')[-1]
        integrated_file = f'{query_file_info["name"].replace("."+file_ext,"_integrated.rds")}'
        uploaded_file = gc.uploadFileToItem(
            itemId = image_file_info['itemId'],
            filepath = f"./{integrated_file}"
        )
        print(f'Uploaded file: {integrated_file} into item: {image_file_info["itemId"]}')
        
if __name__=='__main__':
    main(CLIArgumentParser().parse_args())

