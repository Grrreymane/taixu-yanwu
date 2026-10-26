"""Read-only CPU geometry analysis of the real Godot audit dump. No renderer."""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib
import json
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'build/reports/taixu-mesh-geometry-input.json'
OUTPUT = ROOT / 'build/reports/taixu-mesh-geometry-audit.json'
SOURCE = ROOT.parent / 'hi3-fuhua-extract/exports/c5-material-reference/shader-audit/taixu-uv2'
data = json.loads(INPUT.read_text(encoding='utf-8'))


def arr(surface, name, width):
    return np.asarray(surface[name], dtype=float).reshape(-1, width)


def vkey(v):
    return tuple(np.rint(v * 1e7).astype(np.int64))


def oriented(keys):
    a, b, c = keys
    return min((a, b, c), (b, c, a), (c, a, b))


def inspect(surfaces):
    all_oriented, all_unoriented = Counter(), defaultdict(list)
    rows = []
    for s in surfaces:
        p, n = arr(s, 'positions', 3), arr(s, 'normals', 3)
        indices = np.asarray(s['indices'], dtype=int).reshape(-1, 3)
        tri = p[indices]
        cross = np.cross(tri[:, 1]-tri[:, 0], tri[:, 2]-tri[:, 0])
        lengths = np.linalg.norm(cross, axis=1)
        mean_normal = n[indices].mean(axis=1)
        agreement = np.einsum('ij,ij->i', -cross, mean_normal) / np.maximum(1e-12, lengths*np.linalg.norm(mean_normal, axis=1))
        for index, face in enumerate(tri):
            keys = [vkey(v) for v in face]
            all_oriented[(s['surface'], oriented(keys))] += 1
            all_unoriented[tuple(sorted(keys))].append([s['surface'], index])
        rows.append({'surface': s['surface'], 'vertices': len(p), 'triangles': len(indices),
                     'degenerateAreaUnder1e-12': int(np.sum(lengths < 1e-12)),
                     'geometricNormalOpposesMeanVertexNormal': int(np.sum(agreement < -0.2)),
                     'uv2Vertices': len(s['uv2'])//2,
                     'bounds': [p.min(axis=0).tolist(), p.max(axis=0).tolist()]})
    duplicates = [v for v in all_unoriented.values() if len(v) > 1]
    return {'surfaces': rows, 'coincidentTriangleGroups': len(duplicates),
            'extraCoincidentTriangles': sum(len(v)-1 for v in duplicates),
            'coincidentExamples': duplicates[:16]}, all_oriented


original, original_faces = inspect(data['original'])
restored, restored_faces = inspect(data['restored'])
native = json.loads((SOURCE/'native-body-uv.json').read_text(encoding='utf-8-sig'))[0]
mapping = json.loads((SOURCE/'body-reconstruction-data.json').read_text(encoding='utf-8-sig'))
source_uv2 = np.asarray(native['uv1'], dtype=float).reshape(-1, 2)
uv_rows = []
for s, m in zip(data['restored'], mapping):
    expected = source_uv2[np.asarray(m['sourceVertexIds'], dtype=int)].copy()
    expected[:, 1] = 1.0-expected[:, 1]
    expected = expected.astype(np.float32).astype(float)
    actual = arr(s, 'uv2', 2)
    uv_rows.append({'surface': s['surface'], 'maximumUV2ErrorAgainstOriginalFloat32': float(np.max(np.abs(expected-actual))),
                    'nonFinite': int(np.sum(~np.isfinite(actual))), 'outsideUnitSquare': int(np.sum(np.any((actual < 0) | (actual > 1), axis=1)))})


def segment_triangle(start, end, triangle):
    """Strict interior crossings, excluding coplanar contacts and shared edges."""
    direction = end-start
    e1, e2 = triangle[1]-triangle[0], triangle[2]-triangle[0]
    h = np.cross(direction, e2)
    determinant = np.dot(e1, h)
    if abs(determinant) < 1e-11:
        return None
    inv = 1.0/determinant
    s = start-triangle[0]
    u = inv*np.dot(s, h)
    q = np.cross(s, e1)
    v = inv*np.dot(direction, q)
    t = inv*np.dot(e2, q)
    if min(u, v, 1-u-v, t, 1-t) > 1e-5:
        return start+t*direction
    return None


def crossings(tri, labels):
    low, high = tri.min(axis=1), tri.max(axis=1)
    # Inspect the outer lower half of the visible left skirt, not the face,
    # boot/leg contact, tassels, or the thick belt shown elsewhere in the model.
    centers = tri.mean(axis=1)
    candidates = np.flatnonzero((centers[:, 0] < -0.10) & (centers[:, 1] > 0.50) & (centers[:, 1] < 1.40))
    found, tested = [], 0
    pairs = set()
    for i in candidates:
        broad = np.flatnonzero(np.all(high > low[i]+1e-7, axis=1) & np.all(low < high[i]-1e-7, axis=1))
        for j in broad:
            if i == j or (min(i, j), max(i, j)) in pairs:
                continue
            pairs.add((min(i, j), max(i, j)))
            if np.min(np.linalg.norm(tri[i][:, None, :]-tri[j][None, :, :], axis=2)) < 1e-5:
                continue
            tested += 1
            point = None
            for a, b in ((tri[i], tri[j]), (tri[j], tri[i])):
                for edge in range(3):
                    point = segment_triangle(a[edge], a[(edge+1)%3], b)
                    if point is not None:
                        break
                if point is not None:
                    break
            if point is not None:
                found.append({'triangles': [labels[i], labels[j]], 'point': point.tolist()})
    return {'region': 'actor-local world x < -0.10 m, 0.50 < y < 1.40 m; outer left lower garment',
            'trianglesInRegion': len(candidates), 'nonAdjacentCandidatePairsTested': tested,
            'strictCrossings': len(found), 'examples': found[:12]}


def outline_overlap(tri, normals, labels):
    # Match the normal menu camera relative to player.x=1.9. The body shader is
    # double-sided. The outline moves clip XY by .92px but leaves Z/W unchanged.
    camera = np.array([-1.1, 1.85, 7.6])
    forward = np.array([0.0, -0.37, -7.6]); forward /= np.linalg.norm(forward)
    right = np.cross(forward, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    axes = np.array([right, up, forward])
    width, height, f = 1440, 900, 1.0/np.tan(np.deg2rad(17.0))
    view = (tri-camera) @ axes.T
    projected = view[..., :2]/view[..., 2:3] * (f*height/2)
    nv = normals @ axes.T
    nd = nv[..., :2] * np.array([f/(width/height), f])
    nd /= np.maximum(1e-12, np.linalg.norm(nd, axis=2))[..., None]
    outlined = projected+nd*0.92
    face_normal = -np.cross(tri[:, 1]-tri[:, 0], tri[:, 2]-tri[:, 0])
    center = tri.mean(axis=1)
    back = np.einsum('ij,ij->i', face_normal, camera-center) < 0
    region = (center[:, 0] < -0.10) & (center[:, 1] > 0.50) & (center[:, 1] < 1.40)
    examples, overlaps, in_front = [], 0, 0
    for i in np.flatnonzero(back & region):
        sample = outlined[i].mean(axis=0)
        a, b, c = projected[i]
        matrix = np.stack([b-a, c-a], axis=1)
        if abs(np.linalg.det(matrix)) < 1e-8:
            continue
        uv = np.linalg.solve(matrix, sample-a)
        weights = np.array([1-uv.sum(), uv[0], uv[1]])
        if weights.min() < 0:
            continue
        overlaps += 1
        body_depth = 1/np.sum(weights/view[i, :, 2])
        outline_depth = 1/np.mean(1/view[i, :, 2])
        if outline_depth < body_depth-1e-8:
            in_front += 1
            if len(examples) < 10:
                examples.append({'triangle': labels[i], 'center': center[i].tolist(),
                                 'outlineNearerThanOwnBodyByMeters': float(body_depth-outline_depth)})
    return {'backFacingTrianglesInRegion': int(np.sum(back & region)), 'outlineCentersInsideOwnBodyTriangle': overlaps,
            'outlineCentersCloserThanOwnBody': in_front, 'examples': examples,
            'limitation': 'Analytic self-overlap candidates, not a full z-buffer. Other geometry may occlude these samples. Reproduce with body next_pass disabled to establish pixel causality.'}


pose_rows = []
for pose in data['poses']:
    triangles, normals, labels = [], [], []
    for s, base in zip(pose['surfaces'], data['restored']):
        indices = np.asarray(base['indices'], dtype=int).reshape(-1, 3)
        triangles.append(arr(s, 'positions', 3)[indices])
        normals.append(arr(s, 'normals', 3)[indices])
        labels += [[s['surface'], i] for i in range(len(indices))]
    tri, ns = np.concatenate(triangles), np.concatenate(normals)
    pose_rows.append({'sourceTime': pose['time'], 'physicalCrossings': crossings(tri, labels),
                      'outlineSelfOverlap': outline_overlap(tri, ns, labels)})

report = {
    'scope': 'Read-only CPU audit of on-disk Godot scene and restored ArrayMesh. No production mutation, no graphics renderer.',
    'originalMesh': original, 'restoredUV2Mesh': restored,
    'orientedGeometricTriangleMultisetIdentical': original_faces == restored_faces,
    'nativeUV2SourceComparison': uv_rows, 'materialBindings': data['materialBindings'],
    'skinBindsUnchanged': data['skinBinds'], 'poseSamples': pose_rows,
    'shaderFindings': [
        'The body uses cull_disabled and shade selection FRONT_FACING ? UV : UV2.',
        'The outline uses cull_front, screen-XY extrusion of 0.92 px, and no Z extrusion/bias.',
        'UV2 affects fragment texture lookup only. It cannot generate or displace geometric surfaces.',
        'A back-facing single cloth sheet is drawn by both body and outline. Shifted outline can be nearer than its own unshifted double-sided body even without mesh penetration.'
    ],
    'limits': 'CPU skinning sampled four static menu source times with the current presentation. Strict noncoplanar intersections only; no full triangle rasterizer or GPU visibility test. GPU next-pass ablation is required to attribute the supplied screenshot conclusively.',
    'resourceSHA256': hashlib.sha256((ROOT/'assets/azure-skin/native-body-uv2.res').read_bytes()).hexdigest()
}
OUTPUT.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'report': str(OUTPUT), 'sameTriangles': report['orientedGeometricTriangleMultisetIdentical'],
                  'originalDuplicates': original['extraCoincidentTriangles'], 'restoredDuplicates': restored['extraCoincidentTriangles'],
                  'maxUV2Error': max(s['maximumUV2ErrorAgainstOriginalFloat32'] for s in uv_rows),
                  'poses': [{'time': r['sourceTime'], 'crossings': r['physicalCrossings']['strictCrossings'],
                             'outlineNearer': r['outlineSelfOverlap']['outlineCentersCloserThanOwnBody']} for r in pose_rows]}))
