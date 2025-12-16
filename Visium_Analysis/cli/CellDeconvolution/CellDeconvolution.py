"""Implementing cell composition deconvolution
"""
import os

from ctk_cli import CLIArgumentParser
import girder_client

import subprocess


def main(args):

    gc = girder_client.GirderClient(
        apiUrl = args.girderApiUrl
    )
    gc.setToken(args.girderToken)

    print('Input arguments:')
    for a in vars(args):
        print(f'{a}: {getattr(args,a)}')

    # print contents of current working directory, see if files were copied over
    print('Contents of working directory')
    print(os.listdir(os.getcwd()+'/'))
    file_info = gc.get(f'/file/{args.counts_file}')

    # Downloading counts file to cwd
    gc.downloadFile(
        args.counts_file,
        path = f'{os.getcwd()}/{file_info["name"]}'
    )
    print('Updated contents of directory')
    print(os.listdir(os.getcwd()+'/'))

    if args.use_reference:
        print(f'Running reference-based cell deconvolution')
        # if args.reference_atlas_path is None:
        #     raise ValueError("Reference atlas path must be provided when using reference-based deconvolution.")

        
        # Still not method implemented
        raise NotImplementedError("Reference-based deconvolution is not yet implemented.")
    
    else:
        print(f'Running reference-free cell deconvolution')
        subprocess.call(['Rscript', '../../utils/cell_deconvolution.r', '"'+file_info['name']+'"'])

        print(os.listdir(os.getcwd()+'/'))

        print(f'Uploading file to {file_info["itemId"]}')
        # Posting integration results to item
        file_ext = file_info['name'].split('.')[-1]
        uploaded_file = gc.uploadFileToItem(
            itemId = file_info['itemId'],
            filepath = f'./{file_info["name"].replace("."+file_ext,"_integrated.rds")}'
        )

        # Putting job parameters to item metadata:
        job_submitter = gc.get('/user/me')
        job_meta = {
            'counts_file': args.counts_file,
            'output_item': file_info['itemId'],
            'user': job_submitter['login']
        }

        gc.put(f'/item/{file_info["itemId"]}/metadata',parameters={'metadata': job_meta})

        
if __name__=='__main__':
    main(CLIArgumentParser().parse_args())

