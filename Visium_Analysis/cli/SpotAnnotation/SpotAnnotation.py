"""Codes for generating spot annotations and posting them to an item"""
import os
import sys
import pandas as pd
import json
import geojson
import girder_client
import subprocess

from ctk_cli import CLIArgumentParser
from fusion_tools.utils.shapes import load_visium, geojson_to_histomics
from Visium_Analysis.utils.spot_aggregation import process_sample_to_spot_json


def get_user_id(gc):
    try:
        user = gc.get("/user/me")
        if not user:
            token_info = gc.get("/token/current")
            if token_info and "userId" in token_info:
                return token_info["userId"]
            return None
        return user["_id"]
    except girder_client.HttpError:
        return None


def get_user_info(gc, id):
    try:
        return gc.get(f'/user/{id}')
    except girder_client.HttpError:
        return None


def get_user_running_jobs(gc, user_id):
    try:
        jobs = gc.get("job", parameters={
            "userId": user_id,
            "handlers": '["celery_handler"]',
            "statuses": '[2]'
        })
        return jobs
    except girder_client.HttpError:
        return []


def get_job(gc, title):
    user_id = get_user_id(gc)
    if not user_id:
        return None, None

    user = get_user_info(gc, user_id)
    running_jobs = get_user_running_jobs(gc, user_id)

    for job in running_jobs:
        if job["title"] == title:
            return job, user['login']

    return None, user['login']


INTEGRATION_DATA_KEYS = [
    f"prediction.score.{l}"
    for l in [
        "celltype.l1","celltype.l2","celltype.l3",
        "annotation.l1","annotation.l2","annotation.l3",
        "ann_level_1","ann_level_2","ann_level_3",
        "class","subclass","cluster","cross-species cluster"
    ]
] + ["predsubclassl1","predsubclassl2","pred_subclass_l1","pred_subclass_l2"]


def main(args):

    TITLE = 'Spot Annotation'
    sys.stdout.flush()

    gc = girder_client.GirderClient(apiUrl=args.girderApiUrl)
    gc.setToken(args.girderToken)

    print("Input arguments:")
    for a in vars(args):
        print(f"{a}: {getattr(args,a)}")

    job, user_login = get_job(gc, TITLE)
    job_id = job['_id'] if job else None

    file_info = gc.get(f'/file/{args.input_file}')
    item_files = list(gc.listFile(file_info['itemId']))

    # ------------------------------------------------------------------
    # Find the correct RDS file automatically
    # ------------------------------------------------------------------

    rds_candidates = [
        f for f in item_files
        if f['name'].endswith('.rds')
    ]

    if not rds_candidates:
        raise RuntimeError("No RDS file found in item")

    # pick most recent
    rds_file = sorted(
        rds_candidates,
        key=lambda x: x['created'],
        reverse=True
    )[0]

    print(f"Using RDS file: {rds_file['name']}")

    file_name_path = os.path.join(os.getcwd(), rds_file['name'])

    gc.downloadFile(
        rds_file['_id'],
        path=file_name_path
    )

    print("Downloaded files:", os.listdir(os.getcwd()))
    print("RDS path:", file_name_path)

    # ------------------------------------------------------------------
    # Run R extraction
    # ------------------------------------------------------------------

    subprocess.run(
        ['Rscript', '../scripts/extract_rds_dataframes.r',
         file_name_path, *INTEGRATION_DATA_KEYS],
        check=True
    )

    # ------------------------------------------------------------------
    # Find output CSV files
    # ------------------------------------------------------------------

    output_csvs = [
        f for f in os.listdir(os.getcwd())
        if f.endswith(".csv") and f != "spot_coordinates.csv"
    ]

    print("Output CSV files:", output_csvs)

    # ------------------------------------------------------------------
    # Locate spot_coordinates.csv
    # ------------------------------------------------------------------

    spot_coords_path = None

    possible_paths = [
        os.path.join(os.getcwd(), "spot_coordinates.csv"),
        "/spot_coordinates.csv",
        "/cli/spot_coordinates.csv",
        "/opt/Visium_Analysis/Visium_Analysis/cli/spot_coordinates.csv"
    ]

    for p in possible_paths:
        if os.path.exists(p):
            spot_coords_path = p
            break

    # fallback search
    if spot_coords_path is None:
        for root, dirs, files in os.walk("/"):
            if "spot_coordinates.csv" in files:
                spot_coords_path = os.path.join(root, "spot_coordinates.csv")
                break

    if spot_coords_path is None:
        raise RuntimeError("spot_coordinates.csv not found")

    print("Using spot coordinates:", spot_coords_path)

    visium_spots = load_visium(spot_coords_path)

    # ------------------------------------------------------------------
    # Cell reference
    # ------------------------------------------------------------------

    if args.cell_reference_file:
        cell_reference_info = gc.get(f'/file/{args.cell_reference_file}')
        cell_reference_path = os.path.join(os.getcwd(),"cell_reference.csv")

        gc.downloadFile(
            args.cell_reference_file,
            path=cell_reference_path
        )
    else:
        cell_reference_path = "../public/cell_reference.csv"

    print("Cell reference:", cell_reference_path)

    # ------------------------------------------------------------------
    # Determine prediction CSVs
    # ------------------------------------------------------------------

    l1_celltype_path = None
    l2_celltype_path = None

    for o in output_csvs:
        if o in ["predsubclassl1.csv","pred_subclass_l1.csv"]:
            l1_celltype_path = o
        if o in ["predsubclassl2.csv","pred_subclass_l2.csv"]:
            l2_celltype_path = o

    visium_spots = process_sample_to_spot_json(
        visium_spots,
        l1_celltype_path,
        l2_celltype_path,
        cell_reference_path
    )

    # ------------------------------------------------------------------
    # Convert to Histomics
    # ------------------------------------------------------------------

    histomics_spots = geojson_to_histomics(visium_spots)

    attributes = {
        "job_id": job_id,
        "plugin": TITLE,
        "user": user_login if user_login else "system"
    }

    histomics_spots[0]['annotation']['attributes'] = attributes

    gc.post(
        f'/annotation/item/{file_info["itemId"]}?token={args.girderToken}',
        data=json.dumps(histomics_spots),
        headers={
            'X-HTTP-Method': 'POST',
            'Content-Type': 'application/json'
        }
    )


if __name__ == "__main__":
    main(CLIArgumentParser().parse_args())