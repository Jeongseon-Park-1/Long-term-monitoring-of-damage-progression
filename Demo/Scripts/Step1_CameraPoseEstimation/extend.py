import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import pycolmap
from tqdm import tqdm

from . import logger
from .utils.io import get_keypoints, get_matches


def create_empty_db(database_path: Path):
    if database_path.exists():
        logger.warning("The database already exists, deleting it.")
        database_path.unlink()
    logger.info("Creating an empty database...")
    with pycolmap.Database.open(database_path) as _:
        pass


def import_images(
    image_dir: Path,
    database_path: Path,
    camera_mode: pycolmap.CameraMode,
    image_list: Optional[List[str]] = None,
    options: Optional[Dict[str, Any]] = None,
):
    logger.info("Importing images into the database...")
    if options is None:
        options = {}
    if not image_dir.exists():
        raise IOError(f"image_dir not found: {image_dir}")

    with pycolmap.ostream():
        pycolmap.import_images(
            database_path,
            image_dir,
            camera_mode,
            image_names=image_list or [],
            options=options,
        )


def get_image_ids(database_path: Path) -> Dict[str, int]:
    with pycolmap.Database.open(database_path) as db:
        return {image.name: image.image_id for image in db.read_all_images()}


def read_pairs(pairs_path: Path) -> List[List[str]]:
    with open(str(pairs_path), "r", encoding="utf-8") as f:
        pairs = [p.strip().split() for p in f.readlines()]
    pairs = [p for p in pairs if len(p) == 2]
    return pairs


def import_features_to_db(image_ids: Dict[str, int], db: pycolmap.Database, features_path: Path):
    logger.info("Importing features into the database...")
    for name, image_id in tqdm(image_ids.items(), total=len(image_ids)):
        kps = get_keypoints(features_path, name)
        if kps is None:
            kps = np.zeros((0, 2), dtype=np.float32)
        kps = np.asarray(kps, dtype=np.float32)
        kps += 0.5  # COLMAP coordinate convention
        db.write_keypoints(image_id, kps)


def import_matches_to_db(
    image_ids: Dict[str, int],
    db: pycolmap.Database,
    pairs_path: Path,
    matches_path: Path,
    min_match_score: Optional[float] = None,
):
    logger.info("Importing matches into the database...")

    pairs = read_pairs(pairs_path)
    logger.info(f"Pairs in file: {len(pairs)}")

    written = set()
    skipped_name = 0
    for name0, name1 in tqdm(pairs, total=len(pairs)):
        if name0 not in image_ids or name1 not in image_ids:
            skipped_name += 1
            continue

        id0, id1 = image_ids[name0], image_ids[name1]

        # avoid duplicates
        key = (min(id0, id1), max(id0, id1))
        if key in written:
            continue
        written.add(key)

        matches, scores = get_matches(matches_path, name0, name1)
        if matches is None:
            matches = np.zeros((0, 2), dtype=np.int32)
            scores = None

        if min_match_score is not None and scores is not None:
            matches = matches[scores > min_match_score]

        db.write_matches(id0, id1, np.asarray(matches, dtype=np.uint32))

    if skipped_name > 0:
        logger.warning(
            f"Skipped {skipped_name} pairs because image names were not found in DB.\n"
            f"Check that names in pairs.txt match the relative paths stored in the DB."
        )


def verify_matches_in_db(database_path: Path, pairs_path: Path, verbose: bool = False):
    logger.info("Performing geometric verification (writes two_view_geometries)...")
    if not verbose:
        pycolmap.logging.alsologtostderr = False
    pycolmap.verify_matches(
        database_path,
        pairs_path,
        options=dict(ransac=dict(max_num_trials=20000, min_inlier_ratio=0.1)),
    )
    if not verbose:
        pycolmap.logging.alsologtostderr = True


def main(
    sfm_dir: Path,
    image_dir: Path,
    pairs: Path,
    features: Path,
    matches: Path,
    camera_mode: pycolmap.CameraMode = pycolmap.CameraMode.AUTO,
    min_match_score: Optional[float] = None,
    image_list: Optional[List[str]] = None,
    image_options: Optional[Dict[str, Any]] = None,
    do_geometric_verification: bool = False,
    verbose: bool = False,
):
    assert pairs.exists(), pairs
    assert features.exists(), features
    assert matches.exists(), matches
    assert image_dir.exists(), image_dir

    sfm_dir.mkdir(parents=True, exist_ok=True)
    database = sfm_dir / "database.db"

    logger.info(f"Writing COLMAP logs to {sfm_dir / 'colmap.LOG.*'}")
    pycolmap.logging.set_log_destination(pycolmap.logging.INFO, sfm_dir / "colmap.LOG.")

    create_empty_db(database)
    import_images(image_dir, database, camera_mode, image_list, image_options)

    image_ids = get_image_ids(database)
    logger.info(f"Imported images in DB: {len(image_ids)}")

    with pycolmap.Database.open(database) as db:
        import_features_to_db(image_ids, db, features)
        import_matches_to_db(image_ids, db, pairs, matches, min_match_score=min_match_score)

    if do_geometric_verification:
        verify_matches_in_db(database, pairs, verbose=verbose)

    logger.info(f"Done. DB saved at: {database}")
    logger.info("Next step (COLMAP GUI): open database.db -> Run Mapper / Point triangulation as you prefer.")
    return database


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sfm_dir", type=Path, required=True)
    parser.add_argument("--image_dir", type=Path, required=True)
    parser.add_argument("--pairs", type=Path, required=True)
    parser.add_argument("--features", type=Path, required=True)
    parser.add_argument("--matches", type=Path, required=True)

    parser.add_argument(
        "--camera_mode",
        type=str,
        default="AUTO",
        choices=list(pycolmap.CameraMode.__members__.keys()),
    )
    parser.add_argument("--min_match_score", type=float, default=None)

    # optional: if you already have a list file you can pass it later by editing the script
    parser.add_argument("--verify", action="store_true", help="Run pycolmap.verify_matches and store two_view_geometries")
    parser.add_argument("--verbose", action="store_true")

    args = parser.parse_args()

    cam_mode = pycolmap.CameraMode.__members__[args.camera_mode]
    main(
        sfm_dir=args.sfm_dir,
        image_dir=args.image_dir,
        pairs=args.pairs,
        features=args.features,
        matches=args.matches,
        camera_mode=cam_mode,
        min_match_score=args.min_match_score,
        do_geometric_verification=args.verify,
        verbose=args.verbose,
    )
