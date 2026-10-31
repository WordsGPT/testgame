#!/usr/bin/env python3
"""
Procedural 3D Asset Generator for FRANC-TIREUR : Opération Écho (Édition Complète A1–B1)
Runs inside headless Blender 4.2 LTS (`blender --background --python generate_blender_assets.py`)
Generates 45 distinct, multi-material 3D vocabulary .blend models across 9 CEFR A1-B1 Sectors
+ blaster.blend + drone.blend + pedestal.blend + holo_crystal.blend (49 total models).
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "models"))
os.makedirs(OUT_DIR, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, color, metallic=0.0, roughness=0.75, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    rgba = (color[0], color[1], color[2], color[3] if len(color) > 3 else 1.0)
    bsdf.inputs["Base Color"].default_value = rgba
    # Enforce a warm, tactile matte-clay / brushed-satin finish (never glossy plastic!)
    actual_metal = metallic * 0.65 if metallic >= 0.4 else 0.0
    actual_rough = max(0.45, roughness) if metallic >= 0.4 else max(0.74, roughness)
    bsdf.inputs["Metallic"].default_value = actual_metal
    bsdf.inputs["Roughness"].default_value = actual_rough
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.16
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = 0.16
    if emission is not None and emission_strength > 0.0:
        em_rgba = (emission[0], emission[1], emission[2], 1.0)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = em_rgba
            bsdf.inputs["Emission Strength"].default_value = min(emission_strength, 0.8)
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = em_rgba
    return mat


def assign_mat(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def shade_smooth(obj):
    if obj.type == "MESH":
        for poly in obj.data.polygons:
            poly.use_smooth = True


def finalize_and_save(filename, target_size=1.15, center_origin=True):
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects created for {filename}")

    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = os.path.splitext(filename)[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if center_origin:
        bbox = [Vector(b) for b in obj.bound_box]
        min_v = Vector((min(v.x for v in bbox), min(v.y for v in bbox), min(v.z for v in bbox)))
        max_v = Vector((max(v.x for v in bbox), max(v.y for v in bbox), max(v.z for v in bbox)))
        center = (min_v + max_v) * 0.5
        dims = max_v - min_v
        max_dim = max(dims.x, dims.y, dims.z, 0.001)
        scale_factor = target_size / max_dim
        for v in obj.data.vertices:
            v.co = (v.co - center) * scale_factor
        obj.data.update()

    tri_mod = obj.modifiers.new("Triangulate", "TRIANGULATE")
    tri_mod.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=tri_mod.name)

    path = os.path.join(OUT_DIR, filename)
    bpy.ops.wm.save_as_mainfile(filepath=path)


def add_sphere(loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), mat=None, seg=26, ring=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    shade_smooth(o)
    if mat:
        assign_mat(o, mat)
    return o


def add_cyl(loc=(0, 0, 0), r=0.5, depth=1.0, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, verts=22, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    if smooth:
        shade_smooth(o)
    if mat:
        assign_mat(o, mat)
    return o


def add_cone(loc=(0, 0, 0), r1=0.5, r2=0.0, depth=1.0, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, verts=22, smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    if smooth:
        shade_smooth(o)
    if mat:
        assign_mat(o, mat)
    return o


def add_cube(loc=(0, 0, 0), scale=(0.5, 0.5, 0.5), rot=(0, 0, 0), mat=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        shade_smooth(o)
    if mat:
        assign_mat(o, mat)
    return o


def add_torus(loc=(0, 0, 0), major_r=0.5, minor_r=0.1, scale=(1, 1, 1), rot=(0, 0, 0), mat=None, seg=26, min_seg=12):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r, minor_radius=minor_r,
        major_segments=seg, minor_segments=min_seg,
        location=loc, rotation=rot
    )
    o = bpy.context.active_object
    o.scale = scale
    shade_smooth(o)
    if mat:
        assign_mat(o, mat)
    return o


# ==============================================================================
# SECTORS 1–4 (A1 / A1+ — 20 MODELS)
# ==============================================================================

def build_pomme():
    reset_scene()
    red = make_mat("AppleRed", (0.88, 0.06, 0.09), metallic=0.05, roughness=0.22)
    stem_m = make_mat("StemBrown", (0.38, 0.20, 0.07), roughness=0.62)
    leaf_m = make_mat("LeafGreen", (0.10, 0.82, 0.22), roughness=0.25, emission=(0.04, 0.26, 0.06), emission_strength=0.18)
    apple = add_sphere(seg=40, ring=28, mat=red)
    for v in apple.data.vertices:
        x, y, z = v.co.x, v.co.y, v.co.z
        r_xy = math.hypot(x, y)
        # Classic apple profile: full rounded shoulders (z > 0), tapered lower cup (z < 0)
        profile = 0.88 + 0.15 * z + 0.08 * (1.0 - z * z)
        top_dip = 0.38 * math.exp(-((r_xy / 0.44) ** 2)) if z > 0.10 else 0.0
        bot_dip = 0.22 * math.exp(-((r_xy / 0.36) ** 2)) if z < -0.10 else 0.0
        z_new = z * 0.96 - top_dip + bot_dip
        ang = math.atan2(y, x)
        lobe = 1.0 + 0.03 * math.cos(5.0 * ang) * (r_xy ** 2)
        v.co = Vector((x * profile * lobe, y * profile * lobe, z_new))
    apple.data.update()
    shade_smooth(apple)
    # Prominent woody stem rising well above the top dimple
    stem = add_cyl(loc=(0.02, 0.0, 0.96), r=0.068, depth=0.56, rot=(0.0, 0.22, 0.0), mat=stem_m, verts=16)
    for v in stem.data.vertices:
        if v.co.z > 0:
            v.co.x += 0.06 * (v.co.z / 0.28) ** 2
    stem.data.update()
    # Vibrant green leaf arching out from the stem above the shoulder
    leaf = add_sphere(loc=(0.34, 0.0, 1.08), scale=(0.42, 0.22, 0.08), rot=(0.38, -0.28, 0.12), mat=leaf_m, seg=24, ring=14)
    for v in leaf.data.vertices:
        taper = max(0.08, 1.0 - abs(v.co.x) * 0.72)
        v.co.y *= taper
        v.co.z += 0.12 * (v.co.x ** 2)
    leaf.data.update()
    finalize_and_save("pomme.blend", 1.34)


def build_fromage():
    reset_scene()
    yellow = make_mat("CheeseYellow", (0.98, 0.78, 0.16), roughness=0.42)
    rind = make_mat("CheeseRind", (0.82, 0.56, 0.08), roughness=0.55)
    hole_m = make_mat("CheeseHole", (0.86, 0.62, 0.10), roughness=0.5)
    mesh = bpy.data.meshes.new("WedgeMesh")
    bm = bmesh.new()
    arc_pts, radius, half_ang, h = 9, 1.25, 0.42, 0.65
    tip_bot = bm.verts.new((-0.65, 0.0, -h * 0.5))
    tip_top = bm.verts.new((-0.65, 0.0, h * 0.5))
    bot_arc, top_arc = [], []
    for i in range(arc_pts):
        ang = -half_ang + (2 * half_ang) * i / (arc_pts - 1)
        x, y = -0.65 + radius * math.cos(ang), radius * math.sin(ang)
        bot_arc.append(bm.verts.new((x, y, -h * 0.5)))
        top_arc.append(bm.verts.new((x, y, h * 0.5)))
    for i in range(arc_pts - 1):
        bm.faces.new((tip_top, top_arc[i], top_arc[i + 1]))
        bm.faces.new((tip_bot, bot_arc[i + 1], bot_arc[i]))
        bm.faces.new((bot_arc[i], bot_arc[i + 1], top_arc[i + 1], top_arc[i]))
    bm.faces.new((tip_bot, bot_arc[0], top_arc[0], tip_top))
    bm.faces.new((tip_bot, tip_top, top_arc[-1], bot_arc[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    w_obj = bpy.data.objects.new("Wedge", mesh)
    bpy.context.collection.objects.link(w_obj)
    assign_mat(w_obj, yellow)
    for i in range(5):
        ang = -0.34 + 0.68 * i / 4.0
        add_cube(loc=(-0.65 + 1.26 * math.cos(ang), 1.26 * math.sin(ang), 0), scale=(0.06, 0.24, 0.66), rot=(0, 0, ang), mat=rind, bevel=0.01)
    for hx, hy, hz, hr in [(-0.15, 0.08, 0.33, 0.13), (0.22, -0.16, 0.33, 0.16), (0.10, 0.22, 0.33, 0.10), (0.05, -0.22, 0.05, 0.13), (0.32, 0.28, -0.08, 0.14)]:
        add_sphere(loc=(hx, hy, hz), scale=(hr, hr, hr * 0.55), mat=hole_m, seg=14, ring=10)
    finalize_and_save("fromage.blend", 1.15)


def build_pain():
    reset_scene()
    crust = make_mat("BaguetteCrust", (0.76, 0.45, 0.16), roughness=0.62)
    crumb = make_mat("BaguetteSlash", (0.95, 0.84, 0.58), roughness=0.72)
    loaf = add_sphere(scale=(1.15, 0.28, 0.23), mat=crust, seg=30, ring=16)
    for v in loaf.data.vertices:
        v.co.y += 0.07 * (1.0 - (v.co.x / 1.15) ** 2)
        if v.co.z < -0.12:
            v.co.z = -0.12 + (v.co.z + 0.12) * 0.25
    loaf.data.update()
    for sx in (-0.62, -0.21, 0.21, 0.62):
        add_sphere(loc=(sx, 0.05, 0.20), scale=(0.17, 0.07, 0.05), rot=(0, 0, 0.58), mat=crumb, seg=14, ring=10)
    finalize_and_save("pain.blend", 1.25)


def build_bouteille():
    reset_scene()
    glass = make_mat("EmeraldGlass", (0.08, 0.52, 0.22), metallic=0.15, roughness=0.14)
    label = make_mat("WineLabel", (0.95, 0.91, 0.79), roughness=0.65)
    stripe = make_mat("LabelAccent", (0.68, 0.12, 0.16), roughness=0.5)
    cork = make_mat("Cork", (0.72, 0.53, 0.31), roughness=0.8)
    add_cyl(loc=(0, 0, -0.35), r=0.34, depth=0.95, mat=glass, verts=26)
    add_sphere(loc=(0, 0, 0.12), scale=(0.34, 0.34, 0.28), mat=glass, seg=26, ring=14)
    add_cyl(loc=(0, 0, 0.56), r=0.12, depth=0.55, mat=glass, verts=22)
    add_torus(loc=(0, 0, 0.81), major_r=0.13, minor_r=0.03, mat=glass)
    add_cyl(loc=(0, 0, 0.92), r=0.095, depth=0.20, mat=cork, verts=18)
    add_cyl(loc=(0, 0, -0.32), r=0.348, depth=0.44, mat=label, verts=26)
    add_cyl(loc=(0, 0, -0.15), r=0.351, depth=0.06, mat=stripe, verts=26)
    finalize_and_save("bouteille.blend", 1.22)


def build_tasse():
    reset_scene()
    ceramic = make_mat("WhiteCeramic", (0.94, 0.95, 0.98), roughness=0.20)
    rim_blue = make_mat("CobaltRim", (0.14, 0.34, 0.78), roughness=0.25)
    coffee = make_mat("Espresso", (0.18, 0.09, 0.04), roughness=0.12)
    add_cone(loc=(0, 0, -0.42), r1=0.52, r2=0.78, depth=0.11, mat=ceramic, verts=28)
    add_torus(loc=(0, 0, -0.36), major_r=0.77, minor_r=0.025, mat=rim_blue)
    add_cone(loc=(0, 0, 0.02), r1=0.34, r2=0.48, depth=0.76, mat=ceramic, verts=28)
    add_torus(loc=(0, 0, 0.40), major_r=0.47, minor_r=0.03, mat=rim_blue)
    add_cyl(loc=(0, 0, 0.33), r=0.43, depth=0.05, mat=coffee, verts=24)
    add_torus(loc=(0.50, 0, 0.04), major_r=0.22, minor_r=0.055, rot=(math.pi * 0.5, 0, 0), mat=ceramic)
    finalize_and_save("tasse.blend", 1.10)


def build_livre():
    reset_scene()
    cover = make_mat("RoyalCover", (0.12, 0.25, 0.68), roughness=0.42)
    pages = make_mat("IvoryPages", (0.96, 0.94, 0.87), roughness=0.70)
    gold = make_mat("GoldFoil", (0.94, 0.76, 0.22), metallic=0.82, roughness=0.25)
    ribbon = make_mat("RibbonRed", (0.82, 0.11, 0.16), roughness=0.45)
    add_cube(loc=(0.02, 0, 0.19), scale=(0.82, 1.06, 0.05), mat=cover, bevel=0.015)
    add_cube(loc=(0.02, 0, -0.19), scale=(0.82, 1.06, 0.05), mat=cover, bevel=0.015)
    add_cyl(loc=(-0.39, 0, 0), r=0.215, depth=1.06, rot=(math.pi * 0.5, 0, 0), mat=cover, verts=18)
    add_cube(loc=(0.04, 0, 0), scale=(0.76, 1.00, 0.33), mat=pages, bevel=0.01)
    for sy in (-0.34, 0.0, 0.34):
        add_cyl(loc=(-0.40, sy, 0), r=0.222, depth=0.045, rot=(math.pi * 0.5, 0, 0), mat=gold, verts=18)
    add_cube(loc=(0.06, 0.12, 0.22), scale=(0.36, 0.44, 0.02), mat=gold, bevel=0.005)
    add_cube(loc=(0.12, -0.60, -0.02), scale=(0.09, 0.26, 0.02), rot=(0, 0, 0.15), mat=ribbon, bevel=0.004)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.95, orient_axis="X")
    finalize_and_save("livre.blend", 1.15)


def build_cle():
    reset_scene()
    gold = make_mat("BrassKey", (0.95, 0.75, 0.18), metallic=0.85, roughness=0.22)
    gem = make_mat("KeyGem", (0.12, 0.68, 0.88), metallic=0.2, roughness=0.15, emission=(0.1, 0.5, 0.8), emission_strength=0.4)
    add_torus(loc=(-0.55, 0, 0), major_r=0.30, minor_r=0.075, rot=(math.pi * 0.5, 0, 0), mat=gold)
    add_sphere(loc=(-0.55, 0, 0), scale=(0.11, 0.06, 0.11), mat=gem)
    add_torus(loc=(-0.20, 0, 0), major_r=0.10, minor_r=0.04, rot=(0, math.pi * 0.5, 0), mat=gold)
    add_cyl(loc=(0.28, 0, 0), r=0.065, depth=1.02, rot=(0, math.pi * 0.5, 0), mat=gold, verts=18)
    add_cube(loc=(0.52, 0, -0.17), scale=(0.12, 0.07, 0.24), mat=gold, bevel=0.015)
    add_cube(loc=(0.70, 0, -0.14), scale=(0.10, 0.07, 0.18), mat=gold, bevel=0.015)
    add_cube(loc=(0.61, 0, -0.25), scale=(0.30, 0.07, 0.08), mat=gold, bevel=0.015)
    finalize_and_save("cle.blend", 1.20)


def build_horloge():
    reset_scene()
    brass = make_mat("ClockRim", (0.85, 0.64, 0.18), metallic=0.80, roughness=0.25)
    face = make_mat("ClockFace", (0.97, 0.96, 0.92), roughness=0.35)
    dark = make_mat("ClockHands", (0.09, 0.10, 0.13), roughness=0.3)
    red = make_mat("CenterPin", (0.88, 0.14, 0.14), roughness=0.25)
    add_cyl(loc=(0, 0, 0), r=0.62, depth=0.16, rot=(math.pi * 0.5, 0, 0), mat=face, verts=32)
    add_torus(loc=(0, -0.05, 0), major_r=0.62, minor_r=0.075, rot=(math.pi * 0.5, 0, 0), mat=brass, seg=32)
    add_cyl(loc=(0, 0.05, 0), r=0.63, depth=0.06, rot=(math.pi * 0.5, 0, 0), mat=brass, verts=32)
    for side in (-0.09, 0.09):
        for i in range(12):
            ang = i * (2.0 * math.pi / 12.0)
            sz = 0.09 if i % 3 == 0 else 0.055
            add_cube(loc=(0.48 * math.sin(ang), side, 0.48 * math.cos(ang)), scale=(0.035, 0.02, sz), rot=(0, -ang, 0), mat=dark, bevel=0.004)
        add_cube(loc=(-0.11, side * 1.15, 0.08), scale=(0.045, 0.025, 0.28), rot=(0, 0.95, 0), mat=dark, bevel=0.005)
        add_cube(loc=(0.15, side * 1.25, 0.13), scale=(0.035, 0.025, 0.40), rot=(0, -0.85, 0), mat=dark, bevel=0.005)
        add_sphere(loc=(0, side * 1.35, 0), scale=(0.055, 0.04, 0.055), mat=red)
    add_torus(loc=(0, 0, 0.73), major_r=0.10, minor_r=0.028, rot=(math.pi * 0.5, 0, 0), mat=brass)
    finalize_and_save("horloge.blend", 1.15)


def build_lanterne():
    reset_scene()
    iron = make_mat("WroughtIron", (0.15, 0.17, 0.21), metallic=0.75, roughness=0.42)
    flame = make_mat("WarmGlow", (1.0, 0.72, 0.18), roughness=0.15, emission=(1.0, 0.62, 0.12), emission_strength=2.2)
    add_cyl(loc=(0, 0, -0.52), r=0.38, depth=0.12, mat=iron, verts=6, smooth=False)
    add_cone(loc=(0, 0, 0.46), r1=0.46, r2=0.08, depth=0.32, mat=iron, verts=6, smooth=False)
    add_cyl(loc=(0, 0, 0.65), r=0.10, depth=0.12, mat=iron, verts=12)
    add_torus(loc=(0, 0, 0.78), major_r=0.11, minor_r=0.028, rot=(math.pi * 0.5, 0, 0), mat=iron)
    add_cyl(loc=(0, 0, -0.05), r=0.26, depth=0.78, mat=flame, verts=18)
    for i in range(6):
        ang = i * math.pi / 3.0
        add_cyl(loc=(0.33 * math.cos(ang), 0.33 * math.sin(ang), -0.04), r=0.028, depth=0.88, mat=iron, verts=10)
    finalize_and_save("lanterne.blend", 1.20)


def build_lunettes():
    reset_scene()
    frame = make_mat("GlassesFrame", (0.10, 0.11, 0.14), metallic=0.3, roughness=0.25)
    lens = make_mat("CyanLens", (0.22, 0.78, 0.96), metallic=0.35, roughness=0.08, emission=(0.10, 0.45, 0.65), emission_strength=0.45)
    hinge = make_mat("GoldHinge", (0.92, 0.75, 0.22), metallic=0.85, roughness=0.2)
    for sx in (-0.36, 0.36):
        add_torus(loc=(sx, 0, 0), major_r=0.25, minor_r=0.045, rot=(math.pi * 0.5, 0, 0), mat=frame, seg=26)
        add_cyl(loc=(sx, 0, 0), r=0.23, depth=0.035, rot=(math.pi * 0.5, 0, 0), mat=lens, verts=26)
        add_cube(loc=(sx * 1.72, 0.34, 0.04), scale=(0.045, 0.68, 0.055), mat=frame, bevel=0.01)
        add_cube(loc=(sx * 1.72, 0.02, 0.04), scale=(0.08, 0.06, 0.07), mat=hinge, bevel=0.008)
    add_torus(loc=(0, -0.02, 0.05), major_r=0.11, minor_r=0.032, rot=(math.pi * 0.5, 0, 0), mat=frame)
    finalize_and_save("lunettes.blend", 1.20)


def build_epee():
    reset_scene()
    steel = make_mat("BladeSteel", (0.84, 0.88, 0.94), metallic=0.92, roughness=0.14)
    gold = make_mat("HiltGold", (0.94, 0.74, 0.18), metallic=0.86, roughness=0.22)
    grip = make_mat("LeatherGrip", (0.36, 0.16, 0.08), roughness=0.65)
    ruby = make_mat("PommelRuby", (0.90, 0.08, 0.18), metallic=0.2, roughness=0.12, emission=(0.6, 0.04, 0.1), emission_strength=0.5)
    add_cone(loc=(0, 0, 0.82), r1=0.13, r2=0.01, depth=0.45, scale=(1.0, 0.25, 1.0), mat=steel, verts=4, smooth=False)
    add_cyl(loc=(0, 0, 0.12), r=0.13, depth=0.96, scale=(1.0, 0.25, 1.0), mat=steel, verts=4, smooth=False)
    add_cube(loc=(0, 0, -0.37), scale=(0.56, 0.11, 0.09), mat=gold, bevel=0.02)
    add_sphere(loc=(0, 0, -0.37), scale=(0.10, 0.08, 0.09), mat=ruby)
    add_cyl(loc=(0, 0, -0.58), r=0.055, depth=0.34, mat=grip, verts=16)
    add_sphere(loc=(0, 0, -0.79), scale=(0.095, 0.095, 0.095), mat=gold)
    add_sphere(loc=(0, 0, -0.84), scale=(0.055, 0.055, 0.055), mat=ruby)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.48, orient_axis="Y")
    finalize_and_save("epee.blend", 1.28)


def build_bouclier():
    reset_scene()
    blue = make_mat("RoyalShield", (0.11, 0.30, 0.78), metallic=0.25, roughness=0.32)
    silver = make_mat("ShieldRim", (0.80, 0.84, 0.90), metallic=0.88, roughness=0.22)
    gold = make_mat("ShieldBoss", (0.95, 0.76, 0.18), metallic=0.86, roughness=0.20)
    body = add_cyl(loc=(0, 0, 0), r=0.62, depth=0.11, rot=(math.pi * 0.5, 0, 0), mat=blue, verts=26)
    for v in body.data.vertices:
        if v.co.z > 0.36:
            v.co.z = 0.38 + (v.co.z - 0.36) * 0.22
        if v.co.z < 0:
            v.co.x *= max(0.08, 1.0 + v.co.z * 1.15)
        v.co.y -= 0.11 * (1.0 - (v.co.x / 0.65) ** 2)
    body.data.update()
    for sy in (-0.09, 0.07):
        add_sphere(loc=(0, sy, 0.02), scale=(0.17, 0.08, 0.17), mat=gold)
        add_cube(loc=(0, sy * 0.85, 0.02), scale=(0.68, 0.04, 0.09), mat=silver, bevel=0.01)
        add_cube(loc=(0, sy * 0.85, -0.02), scale=(0.09, 0.04, 0.76), mat=silver, bevel=0.01)
    finalize_and_save("bouclier.blend", 1.18)


def build_couronne():
    reset_scene()
    gold = make_mat("CrownGold", (0.97, 0.78, 0.16), metallic=0.88, roughness=0.18)
    velvet = make_mat("RoyalVelvet", (0.68, 0.07, 0.14), roughness=0.72)
    ruby = make_mat("RubyGem", (0.92, 0.08, 0.16), roughness=0.12, emission=(0.5, 0.02, 0.06), emission_strength=0.4)
    emerald = make_mat("EmeraldGem", (0.08, 0.78, 0.32), roughness=0.12, emission=(0.04, 0.4, 0.14), emission_strength=0.4)
    add_cyl(loc=(0, 0, -0.14), r=0.52, depth=0.24, mat=gold, verts=28)
    add_torus(loc=(0, 0, -0.25), major_r=0.52, minor_r=0.045, mat=gold, seg=28)
    add_sphere(loc=(0, 0, -0.06), scale=(0.48, 0.48, 0.24), mat=velvet, seg=22, ring=12)
    for i in range(6):
        ang = i * (2.0 * math.pi / 6.0)
        px, py = 0.50 * math.cos(ang), 0.50 * math.sin(ang)
        add_cone(loc=(px, py, 0.16), r1=0.16, r2=0.01, depth=0.38, mat=gold, verts=12)
        add_sphere(loc=(px, py, 0.36), scale=(0.055, 0.055, 0.055), mat=gold)
        add_sphere(loc=(0.53 * math.cos(ang), 0.53 * math.sin(ang), -0.13), scale=(0.065, 0.065, 0.065), mat=ruby if i % 2 == 0 else emerald)
    finalize_and_save("couronne.blend", 1.12)


def build_chapeau():
    reset_scene()
    felt = make_mat("HatBurgundy", (0.42, 0.12, 0.48), roughness=0.68)
    ribbon = make_mat("HatRibbon", (0.96, 0.76, 0.18), metallic=0.45, roughness=0.32)
    brim = add_cyl(loc=(0, 0, -0.22), r=0.72, depth=0.055, scale=(1.0, 0.90, 1.0), mat=felt, verts=32)
    for v in brim.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r > 0.35:
            v.co.z += 0.12 * ((r - 0.35) / 0.37) ** 2 * (1.0 if abs(v.co.x) > abs(v.co.y) * 0.5 else -0.3)
    brim.data.update()
    crown = add_cone(loc=(0, 0, 0.14), r1=0.40, r2=0.34, depth=0.66, scale=(1.05, 0.92, 1.0), mat=felt, verts=28)
    for v in crown.data.vertices:
        if v.co.z > 0.25 and abs(v.co.y) < 0.16:
            v.co.z -= 0.08 * (1.0 - abs(v.co.y) / 0.16)
    crown.data.update()
    add_cyl(loc=(0, 0, -0.12), r=0.405, depth=0.11, scale=(1.05, 0.92, 1.0), mat=ribbon, verts=28)
    finalize_and_save("chapeau.blend", 1.15)


def build_marteau():
    reset_scene()
    wood = make_mat("AshHandle", (0.64, 0.42, 0.20), roughness=0.58)
    grip = make_mat("RubberGrip", (0.16, 0.17, 0.20), roughness=0.75)
    steel = make_mat("HammerSteel", (0.36, 0.40, 0.46), metallic=0.86, roughness=0.28)
    add_cyl(loc=(0, 0, -0.14), r=0.068, depth=1.08, scale=(1.0, 0.78, 1.0), mat=wood, verts=18)
    add_cyl(loc=(0, 0, -0.45), r=0.078, depth=0.42, scale=(1.0, 0.80, 1.0), mat=grip, verts=18)
    add_cube(loc=(-0.05, 0, 0.42), scale=(0.56, 0.24, 0.24), mat=steel, bevel=0.03)
    add_cyl(loc=(-0.36, 0, 0.42), r=0.125, depth=0.10, rot=(0, math.pi * 0.5, 0), mat=steel, verts=18)
    add_cone(loc=(0.33, 0, 0.42), r1=0.12, r2=0.02, depth=0.26, rot=(0, math.pi * 0.5, 0), scale=(1.0, 0.5, 1.0), mat=steel, verts=14)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=-0.42, orient_axis="Y")
    finalize_and_save("marteau.blend", 1.22)


def build_fleur():
    reset_scene()
    petal_m = make_mat("PinkPetal", (0.95, 0.22, 0.58), roughness=0.35)
    center_m = make_mat("PollenGold", (0.99, 0.82, 0.10), roughness=0.45)
    stem_m = make_mat("StemGreen", (0.14, 0.64, 0.20), roughness=0.42)
    add_cyl(loc=(0, 0, -0.22), r=0.045, depth=0.88, mat=stem_m, verts=14)
    add_sphere(loc=(0.18, 0, -0.24), scale=(0.22, 0.09, 0.035), rot=(0, -0.45, 0), mat=stem_m)
    add_sphere(loc=(-0.18, 0, -0.38), scale=(0.20, 0.08, 0.035), rot=(0, 0.45, 0), mat=stem_m)
    head_parts = [add_sphere(loc=(0, 0, 0.28), scale=(0.17, 0.17, 0.10), mat=center_m)]
    for i in range(6):
        ang = i * (2.0 * math.pi / 6.0)
        head_parts.append(add_sphere(loc=(0.28 * math.cos(ang), 0.28 * math.sin(ang), 0.27), scale=(0.22, 0.14, 0.055), rot=(0, 0, ang), mat=petal_m))
    bpy.ops.object.select_all(action="DESELECT")
    for p in head_parts:
        p.select_set(True)
    bpy.ops.transform.rotate(value=0.95, orient_axis="X", center_override=(0, 0, 0.28))
    finalize_and_save("fleur.blend", 1.20)


def build_coeur():
    reset_scene()
    ruby = make_mat("HeartRuby", (0.95, 0.06, 0.18), metallic=0.18, roughness=0.16, emission=(0.55, 0.02, 0.08), emission_strength=0.35)
    gold = make_mat("HeartGoldTrim", (0.98, 0.80, 0.22), metallic=0.88, roughness=0.18)
    mesh = bpy.data.meshes.new("HeartMesh")
    bm = bmesh.new()

    n_alpha = 24  # Front pole to back pole
    n_t = 64      # Around the classic parametric heart silhouette
    front_pole = bm.verts.new((0.0, -0.38, -0.02))
    back_pole = bm.verts.new((0.0, 0.38, -0.02))

    rings = []
    for ia in range(1, n_alpha):
        alpha = math.pi * ia / n_alpha
        r_scale = (math.sin(alpha)) ** 0.72
        y_val = -0.38 * math.cos(alpha)
        ring = []
        for it in range(n_t):
            t = 2.0 * math.pi * it / n_t
            hx = (math.sin(t) ** 3)
            hz = (13.0 * math.cos(t) - 5.0 * math.cos(2.0 * t) - 2.0 * math.cos(3.0 * t) - math.cos(4.0 * t)) / 16.0
            ring.append(bm.verts.new((hx * r_scale, y_val, -0.02 + (hz + 0.02) * r_scale)))
        rings.append(ring)

    # Cap front & back poles and stitch rings
    for it in range(n_t):
        nxt = (it + 1) % n_t
        bm.faces.new((front_pole, rings[0][nxt], rings[0][it]))
        bm.faces.new((back_pole, rings[-1][it], rings[-1][nxt]))

    for ia in range(len(rings) - 1):
        r1, r2 = rings[ia], rings[ia + 1]
        for it in range(n_t):
            nxt = (it + 1) % n_t
            bm.faces.new((r1[it], r1[nxt], r2[nxt], r2[it]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    h_obj = bpy.data.objects.new("Heart", mesh)
    bpy.context.collection.objects.link(h_obj)
    shade_smooth(h_obj)
    assign_mat(h_obj, ruby)

    # Add a golden diagonal arrow / band for unmistakable 3D silhouette depth
    add_cyl(loc=(0, 0, -0.02), r=0.032, depth=1.85, rot=(0, 0.92, 0), mat=gold, verts=16)
    add_cone(loc=(0.76, 0, 0.56), r1=0.10, r2=0.01, depth=0.22, rot=(0, 0.92, 0), mat=gold, verts=14)
    finalize_and_save("coeur.blend", 1.32)


def build_poisson():
    reset_scene()
    coral = make_mat("CoralFish", (0.98, 0.42, 0.12), roughness=0.28)
    stripe = make_mat("TealStripe", (0.12, 0.78, 0.82), roughness=0.28)
    white = make_mat("EyeWhite", (0.97, 0.97, 0.99), roughness=0.18)
    pupil = make_mat("EyePupil", (0.05, 0.06, 0.08), roughness=0.15)
    add_sphere(loc=(-0.08, 0, 0), scale=(0.56, 0.22, 0.36), mat=coral, seg=28, ring=18)
    add_cyl(loc=(-0.05, 0, 0), r=0.355, depth=0.11, rot=(0, math.pi * 0.5, 0), scale=(1.0, 0.64, 1.0), mat=stripe, verts=24)
    add_cone(loc=(0.56, 0, 0.16), r1=0.22, r2=0.02, depth=0.38, rot=(0, -1.15, 0), scale=(1.0, 0.18, 1.0), mat=stripe, verts=12)
    add_cone(loc=(0.56, 0, -0.16), r1=0.22, r2=0.02, depth=0.38, rot=(0, -1.98, 0), scale=(1.0, 0.18, 1.0), mat=stripe, verts=12)
    add_cone(loc=(-0.02, 0, 0.40), r1=0.22, r2=0.02, depth=0.28, rot=(0, -0.35, 0), scale=(1.0, 0.16, 1.0), mat=coral, verts=12)
    for sy in (-0.21, 0.21):
        add_sphere(loc=(-0.10, sy, -0.08), scale=(0.16, 0.04, 0.09), rot=(0.4 if sy > 0 else -0.4, 0.3, 0), mat=stripe)
        add_sphere(loc=(-0.42, sy * 0.78, 0.08), scale=(0.075, 0.045, 0.075), mat=white)
        add_sphere(loc=(-0.45, sy * 0.92, 0.08), scale=(0.042, 0.035, 0.042), mat=pupil)
    finalize_and_save("poisson.blend", 1.20)


def build_etoile():
    reset_scene()
    gold = make_mat("StarGold", (1.0, 0.82, 0.16), metallic=0.78, roughness=0.20, emission=(0.95, 0.68, 0.08), emission_strength=0.45)
    mesh = bpy.data.meshes.new("StarMesh")
    bm = bmesh.new()
    front = bm.verts.new((0, -0.20, 0))
    back = bm.verts.new((0, 0.20, 0))
    ring_v = []
    for i in range(10):
        ang = i * (math.pi / 5.0) - math.pi * 0.5
        r = 0.68 if i % 2 == 0 else 0.28
        ring_v.append(bm.verts.new((r * math.cos(ang), 0.0, -r * math.sin(ang))))
    for i in range(10):
        nxt = ring_v[(i + 1) % 10]
        bm.faces.new((front, ring_v[i], nxt))
        bm.faces.new((back, nxt, ring_v[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Star", mesh)
    bpy.context.collection.objects.link(obj)
    assign_mat(obj, gold)
    finalize_and_save("etoile.blend", 1.18)


def build_fusee():
    reset_scene()
    white = make_mat("RocketHull", (0.94, 0.95, 0.98), metallic=0.25, roughness=0.22)
    red = make_mat("RocketRed", (0.88, 0.12, 0.15), metallic=0.25, roughness=0.25)
    window = make_mat("RocketPort", (0.18, 0.82, 0.98), roughness=0.1, emission=(0.15, 0.65, 0.95), emission_strength=0.9)
    dark = make_mat("Nozzle", (0.18, 0.20, 0.24), metallic=0.8, roughness=0.35)
    add_sphere(loc=(0, 0, 0.02), scale=(0.28, 0.28, 0.62), mat=white, seg=26, ring=18)
    add_cone(loc=(0, 0, 0.54), r1=0.205, r2=0.01, depth=0.36, mat=red, verts=24)
    add_cyl(loc=(0, 0, -0.16), r=0.275, depth=0.12, mat=red, verts=24)
    add_cone(loc=(0, 0, -0.58), r1=0.16, r2=0.10, depth=0.18, mat=dark, verts=18)
    for sy in (-0.25, 0.25):
        add_torus(loc=(0, sy, 0.16), major_r=0.10, minor_r=0.025, rot=(math.pi * 0.5, 0, 0), mat=dark)
        add_sphere(loc=(0, sy, 0.16), scale=(0.09, 0.04, 0.09), mat=window)
    for i in range(3):
        ang = i * (2.0 * math.pi / 3.0)
        add_cube(loc=(0.28 * math.cos(ang), 0.28 * math.sin(ang), -0.44), scale=(0.26, 0.045, 0.34), rot=(0, 0.25, ang), mat=red, bevel=0.01)
    finalize_and_save("fusee.blend", 1.25)


# ==============================================================================
# SECTOR 5 (A2) — VOYAGES & TRANSPORTS
# ==============================================================================

def build_avion():
    reset_scene()
    hull = make_mat("JetWhite", (0.94, 0.96, 0.99), metallic=0.25, roughness=0.20)
    blue = make_mat("AirFranceBlue", (0.10, 0.34, 0.84), metallic=0.3, roughness=0.25)
    red = make_mat("WingTipRed", (0.88, 0.14, 0.20), roughness=0.3)
    glass = make_mat("CockpitGlass", (0.09, 0.16, 0.28), metallic=0.6, roughness=0.1)
    # Fuselage along X
    add_sphere(loc=(0, 0, 0), scale=(0.82, 0.15, 0.16), mat=hull, seg=28, ring=16)
    add_sphere(loc=(-0.60, 0, 0.05), scale=(0.18, 0.11, 0.08), mat=glass)
    # Swept main wings
    add_cube(loc=(-0.02, 0, -0.02), scale=(0.28, 1.38, 0.035), mat=blue, bevel=0.01)
    for sy in (-0.38, 0.38):
        add_cyl(loc=(-0.08, sy, -0.10), r=0.065, depth=0.26, rot=(0, math.pi * 0.5, 0), mat=hull, verts=16)
    # Tail fin & stabilizers
    add_cone(loc=(0.66, 0, 0.22), r1=0.18, r2=0.05, depth=0.38, scale=(1.1, 0.18, 1.0), rot=(0, 0.28, 0), mat=blue, verts=12)
    add_cube(loc=(0.68, 0, 0.36), scale=(0.14, 0.035, 0.08), mat=red, bevel=0.005)
    add_cube(loc=(0.66, 0, 0.03), scale=(0.16, 0.50, 0.025), mat=hull, bevel=0.005)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=-0.22, orient_axis="Y")
    finalize_and_save("avion.blend", 1.28)


def build_train():
    reset_scene()
    silver = make_mat("TGVSilver", (0.82, 0.85, 0.90), metallic=0.75, roughness=0.22)
    cobalt = make_mat("TGVBlue", (0.10, 0.28, 0.78), metallic=0.35, roughness=0.28)
    orange = make_mat("TGVStripe", (0.96, 0.44, 0.08), roughness=0.32)
    dark = make_mat("TGVGlass", (0.08, 0.11, 0.16), metallic=0.5, roughness=0.12)
    # Sleek TGV body + aerodynamic nose cone
    add_cube(loc=(0.18, 0, 0.02), scale=(1.02, 0.34, 0.36), mat=silver, bevel=0.04)
    nose = add_cone(loc=(-0.54, 0, -0.02), r1=0.20, r2=0.04, depth=0.52, rot=(0, -math.pi * 0.5, 0), scale=(1.0, 0.85, 0.88), mat=silver, verts=20)
    add_cube(loc=(0.16, 0, 0.03), scale=(1.04, 0.355, 0.10), mat=cobalt, bevel=0.01)
    add_cube(loc=(0.16, 0, -0.05), scale=(1.05, 0.36, 0.04), mat=orange, bevel=0.005)
    # Cab windshield + side windows
    add_sphere(loc=(-0.38, 0, 0.10), scale=(0.18, 0.15, 0.09), mat=dark)
    add_cube(loc=(0.24, 0, 0.11), scale=(0.72, 0.365, 0.09), mat=dark, bevel=0.005)
    # Bogie wheels + pantograph on roof
    for wx in (-0.28, 0.05, 0.45):
        add_cyl(loc=(wx, 0, -0.20), r=0.075, depth=0.36, rot=(math.pi * 0.5, 0, 0), mat=dark, verts=16)
    add_cube(loc=(0.35, 0, 0.25), scale=(0.24, 0.16, 0.08), mat=dark, bevel=0.005)
    finalize_and_save("train.blend", 1.28)


def build_voiture():
    reset_scene()
    body_m = make_mat("CarRed", (0.88, 0.12, 0.16), metallic=0.45, roughness=0.20)
    glass = make_mat("CarGlass", (0.20, 0.68, 0.88), metallic=0.4, roughness=0.10)
    tire = make_mat("CarTire", (0.10, 0.11, 0.13), roughness=0.75)
    rim = make_mat("WheelRim", (0.85, 0.88, 0.92), metallic=0.85, roughness=0.2)
    lamp = make_mat("Headlight", (1.0, 0.92, 0.45), roughness=0.1, emission=(1.0, 0.9, 0.4), emission_strength=1.4)
    add_cube(loc=(0, 0, -0.06), scale=(1.16, 0.54, 0.26), mat=body_m, bevel=0.045)
    add_cube(loc=(0.06, 0, 0.17), scale=(0.64, 0.46, 0.24), mat=body_m, bevel=0.05)
    add_cube(loc=(0.06, 0, 0.18), scale=(0.66, 0.48, 0.15), mat=glass, bevel=0.02)
    add_cube(loc=(0.05, 0, 0.18), scale=(0.54, 0.50, 0.15), mat=glass, bevel=0.02)
    for wx in (-0.36, 0.36):
        for wy in (-0.27, 0.27):
            add_cyl(loc=(wx, wy, -0.18), r=0.145, depth=0.10, rot=(math.pi * 0.5, 0, 0), mat=tire, verts=20)
            add_cyl(loc=(wx, wy * 1.06, -0.18), r=0.085, depth=0.11, rot=(math.pi * 0.5, 0, 0), mat=rim, verts=16)
    for wy in (-0.17, 0.17):
        add_sphere(loc=(-0.58, wy, -0.03), scale=(0.04, 0.065, 0.055), mat=lamp)
    finalize_and_save("voiture.blend", 1.22)


def build_velo():
    reset_scene()
    teal = make_mat("BikeTeal", (0.10, 0.72, 0.64), metallic=0.45, roughness=0.25)
    tire = make_mat("BikeTire", (0.11, 0.12, 0.15), roughness=0.72)
    chrome = make_mat("BikeChrome", (0.85, 0.88, 0.92), metallic=0.88, roughness=0.18)
    leather = make_mat("BikeSaddle", (0.42, 0.22, 0.10), roughness=0.6)
    for wx in (-0.48, 0.48):
        add_torus(loc=(wx, 0, -0.18), major_r=0.28, minor_r=0.042, rot=(math.pi * 0.5, 0, 0), mat=tire, seg=28)
        add_torus(loc=(wx, 0, -0.18), major_r=0.235, minor_r=0.018, rot=(math.pi * 0.5, 0, 0), mat=chrome, seg=24)
        add_sphere(loc=(wx, 0, -0.18), scale=(0.045, 0.05, 0.045), mat=chrome)
    # Diamond frame tubes
    add_cyl(loc=(0.0, 0, 0.12), r=0.026, depth=0.62, rot=(0, math.pi * 0.5, 0), mat=teal, verts=12)
    add_cyl(loc=(-0.22, 0, -0.03), r=0.026, depth=0.58, rot=(0, 0.88, 0), mat=teal, verts=12)
    add_cyl(loc=(0.14, 0, 0.0), r=0.026, depth=0.56, rot=(0, -0.35, 0), mat=teal, verts=12)
    add_cyl(loc=(0.32, 0, -0.05), r=0.022, depth=0.46, rot=(0, 0.88, 0), mat=teal, verts=12)
    add_cyl(loc=(-0.38, 0, 0.06), r=0.026, depth=0.64, rot=(0, -0.32, 0), mat=chrome, verts=12)
    # Handlebars & Saddle
    add_cyl(loc=(-0.30, 0, 0.36), r=0.022, depth=0.44, rot=(math.pi * 0.5, 0, 0), mat=chrome, verts=12)
    add_sphere(loc=(0.19, 0, 0.28), scale=(0.14, 0.075, 0.045), mat=leather)
    finalize_and_save("velo.blend", 1.25)


def build_valise():
    reset_scene()
    shell = make_mat("SuitcaseGold", (0.92, 0.62, 0.14), metallic=0.25, roughness=0.32)
    trim = make_mat("SuitcaseDark", (0.14, 0.16, 0.20), roughness=0.55)
    chrome = make_mat("TelescopeRod", (0.82, 0.85, 0.90), metallic=0.85, roughness=0.2)
    tag = make_mat("LuggageTag", (0.90, 0.14, 0.20), roughness=0.35)
    add_cube(loc=(0, 0, -0.08), scale=(0.68, 0.34, 0.86), mat=shell, bevel=0.05)
    for rz in (-0.30, -0.10, 0.10):
        add_cube(loc=(0, 0, rz), scale=(0.70, 0.355, 0.035), mat=trim, bevel=0.008)
    # Telescoping handle
    for sx in (-0.14, 0.14):
        add_cyl(loc=(sx, 0, 0.50), r=0.02, depth=0.34, mat=chrome, verts=12)
    add_cube(loc=(0, 0, 0.67), scale=(0.34, 0.05, 0.045), mat=trim, bevel=0.01)
    add_cube(loc=(0.20, -0.18, 0.28), scale=(0.09, 0.03, 0.15), rot=(0, 0.3, 0), mat=tag, bevel=0.005)
    for wx in (-0.24, 0.24):
        for wy in (-0.11, 0.11):
            add_sphere(loc=(wx, wy, -0.54), scale=(0.055, 0.04, 0.055), mat=trim)
    finalize_and_save("valise.blend", 1.20)


# ==============================================================================
# SECTOR 6 (A2) — MAISON & QUOTIDIEN
# ==============================================================================

def build_chaise():
    reset_scene()
    wood = make_mat("OakChair", (0.68, 0.43, 0.19), roughness=0.52)
    cush = make_mat("RedCushion", (0.82, 0.14, 0.18), roughness=0.65)
    add_cube(loc=(0, 0, -0.06), scale=(0.62, 0.60, 0.08), mat=wood, bevel=0.015)
    add_cube(loc=(0, 0, 0.0), scale=(0.56, 0.54, 0.06), mat=cush, bevel=0.02)
    for lx in (-0.26, 0.26):
        for ly in (-0.25, 0.25):
            add_cyl(loc=(lx, ly, -0.36), r=0.04, depth=0.56, mat=wood, verts=12)
    for lx in (-0.26, 0.26):
        add_cyl(loc=(lx, 0.25, 0.34), r=0.042, depth=0.80, mat=wood, verts=12)
    for bz in (0.22, 0.44, 0.66):
        add_cube(loc=(0, 0.25, bz), scale=(0.54, 0.045, 0.085), mat=wood, bevel=0.01)
    finalize_and_save("chaise.blend", 1.22)


def build_batterie():
    reset_scene()
    dark = make_mat("BatteryBody", (0.12, 0.14, 0.18), metallic=0.65, roughness=0.28)
    copper = make_mat("BatteryCopper", (0.92, 0.54, 0.16), metallic=0.82, roughness=0.22)
    silver = make_mat("BatteryCap", (0.85, 0.88, 0.92), metallic=0.90, roughness=0.18)
    glow = make_mat("ChargeGreen", (0.15, 0.95, 0.42), roughness=0.15, emission=(0.12, 0.92, 0.38), emission_strength=1.8)
    add_cyl(loc=(0, 0, -0.18), r=0.36, depth=0.64, mat=dark, verts=28)
    add_cyl(loc=(0, 0, 0.28), r=0.362, depth=0.32, mat=copper, verts=28)
    add_cyl(loc=(0, 0, 0.45), r=0.35, depth=0.05, mat=silver, verts=28)
    add_cyl(loc=(0, 0, -0.51), r=0.35, depth=0.05, mat=silver, verts=28)
    # Positive terminal nub on top
    add_cyl(loc=(0, 0, 0.53), r=0.13, depth=0.12, mat=silver, verts=22)
    # Glowing charge bars on front & back
    for sy in (-0.355, 0.355):
        for bz in (-0.32, -0.16, 0.0):
            add_cube(loc=(0, sy, bz), scale=(0.24, 0.025, 0.08), mat=glow, bevel=0.005)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.32, orient_axis="Y")
    finalize_and_save("batterie.blend", 1.24)


def build_chaussure():
    reset_scene()
    sole = make_mat("SneakerSole", (0.95, 0.96, 0.98), roughness=0.45)
    upper = make_mat("SneakerRed", (0.88, 0.12, 0.18), roughness=0.38)
    trim = make_mat("SneakerStripe", (0.96, 0.97, 0.99), roughness=0.32)
    dark = make_mat("ShoeInner", (0.14, 0.16, 0.20), roughness=0.65)
    # Thick athletic sole along X
    add_cube(loc=(0.0, 0, -0.26), scale=(1.12, 0.44, 0.14), mat=sole, bevel=0.04)
    add_sphere(loc=(-0.42, 0, -0.21), scale=(0.24, 0.21, 0.09), mat=sole, seg=22, ring=12)
    # Main shoe upper & toe box
    add_sphere(loc=(-0.18, 0, -0.10), scale=(0.46, 0.20, 0.18), mat=upper, seg=26, ring=16)
    add_cube(loc=(0.22, 0, -0.02), scale=(0.56, 0.40, 0.36), mat=upper, bevel=0.06)
    # Collar & tongue
    add_cyl(loc=(0.30, 0, 0.18), r=0.16, depth=0.14, scale=(1.1, 0.95, 1.0), mat=dark, verts=20)
    add_cube(loc=(0.05, 0, 0.15), scale=(0.24, 0.26, 0.22), rot=(0, -0.55, 0), mat=upper, bevel=0.03)
    # White laces & side stripes
    for lx in (-0.12, -0.02, 0.08):
        add_cube(loc=(lx, 0, 0.08 - lx * 0.35), scale=(0.045, 0.28, 0.035), mat=trim, bevel=0.005)
    for sy in (-0.205, 0.205):
        add_cube(loc=(0.12, sy, -0.06), scale=(0.42, 0.02, 0.07), rot=(0, 0.28, 0), mat=trim, bevel=0.004)
    finalize_and_save("chaussure.blend", 1.28)


def build_parapluie():
    reset_scene()
    canopy = make_mat("UmbrellaBlue", (0.14, 0.38, 0.90), roughness=0.40)
    accent = make_mat("UmbrellaRed", (0.90, 0.18, 0.24), roughness=0.40)
    shaft = make_mat("SilverShaft", (0.82, 0.85, 0.90), metallic=0.85, roughness=0.2)
    handle = make_mat("WoodHook", (0.46, 0.24, 0.10), roughness=0.5)
    add_cone(loc=(0, 0, 0.28), r1=0.72, r2=0.04, depth=0.40, mat=canopy, verts=8, smooth=False)
    add_torus(loc=(0, 0, 0.10), major_r=0.69, minor_r=0.022, mat=accent, seg=8)
    add_cone(loc=(0, 0, 0.54), r1=0.04, r2=0.008, depth=0.16, mat=shaft, verts=12)
    add_cyl(loc=(0, 0, -0.14), r=0.028, depth=0.86, mat=shaft, verts=14)
    add_torus(loc=(0.09, 0, -0.56), major_r=0.09, minor_r=0.032, rot=(math.pi * 0.5, 0, 0), mat=handle, seg=18)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.24, orient_axis="Y")
    finalize_and_save("parapluie.blend", 1.24)


def build_sac():
    reset_scene()
    fabric = make_mat("BackpackOlive", (0.20, 0.52, 0.32), roughness=0.68)
    leather = make_mat("TanStraps", (0.68, 0.42, 0.18), roughness=0.55)
    gold = make_mat("BuckleGold", (0.94, 0.78, 0.20), metallic=0.85, roughness=0.22)
    add_sphere(loc=(0, 0, 0.0), scale=(0.42, 0.28, 0.52), mat=fabric, seg=24, ring=16)
    add_cube(loc=(0, -0.22, -0.18), scale=(0.54, 0.18, 0.36), mat=fabric, bevel=0.05)
    add_sphere(loc=(0, -0.02, 0.34), scale=(0.40, 0.29, 0.22), mat=leather, seg=22, ring=12)
    for sx in (-0.18, 0.18):
        add_cube(loc=(sx, -0.25, 0.12), scale=(0.075, 0.06, 0.48), mat=leather, bevel=0.01)
        add_cube(loc=(sx, -0.29, 0.04), scale=(0.10, 0.04, 0.09), mat=gold, bevel=0.008)
        add_torus(loc=(sx, 0.22, 0.02), major_r=0.26, minor_r=0.04, rot=(0, math.pi * 0.5, 0), mat=leather, seg=18)
    add_torus(loc=(0, 0.05, 0.54), major_r=0.10, minor_r=0.025, rot=(math.pi * 0.5, 0, 0), mat=leather)
    finalize_and_save("sac.blend", 1.18)


# ==============================================================================
# SECTOR 7 (A2+) — TECHNOLOGIE & MÉDIAS
# ==============================================================================

def build_ordinateur():
    reset_scene()
    alu = make_mat("LaptopAlu", (0.76, 0.80, 0.86), metallic=0.78, roughness=0.25)
    dark = make_mat("KeyDeck", (0.12, 0.14, 0.18), roughness=0.45)
    screen = make_mat("ScreenGlow", (0.16, 0.78, 0.98), roughness=0.12, emission=(0.12, 0.62, 0.92), emission_strength=1.4)
    # Base keyboard deck
    add_cube(loc=(0, -0.12, -0.26), scale=(0.94, 0.64, 0.045), mat=alu, bevel=0.015)
    add_cube(loc=(0, -0.08, -0.23), scale=(0.82, 0.36, 0.015), mat=dark, bevel=0.004)
    # Open screen lid tilted back slightly
    add_cube(loc=(0, 0.25, 0.08), scale=(0.94, 0.04, 0.64), rot=(0.24, 0, 0), mat=alu, bevel=0.015)
    add_cube(loc=(0, 0.23, 0.08), scale=(0.86, 0.02, 0.55), rot=(0.24, 0, 0), mat=screen, bevel=0.005)
    finalize_and_save("ordinateur.blend", 1.20)


def build_telephone():
    reset_scene()
    body = make_mat("PhoneTitanium", (0.18, 0.21, 0.27), metallic=0.82, roughness=0.24)
    screen = make_mat("PhoneDisplay", (0.18, 0.85, 0.96), roughness=0.08, emission=(0.14, 0.68, 0.90), emission_strength=1.5)
    accent = make_mat("AppAccent", (0.98, 0.42, 0.22), roughness=0.2, emission=(0.9, 0.35, 0.15), emission_strength=1.0)
    add_cube(loc=(0, 0, 0), scale=(0.54, 0.08, 1.06), mat=body, bevel=0.04)
    add_cube(loc=(0, -0.038, 0), scale=(0.48, 0.02, 0.96), mat=screen, bevel=0.02)
    for ay in (-0.24, 0.04, 0.30):
        add_cube(loc=(0, -0.048, ay), scale=(0.36, 0.015, 0.13), mat=accent if ay > 0.2 else body, bevel=0.01)
    # Camera bump on back
    add_cube(loc=(-0.12, 0.045, 0.34), scale=(0.20, 0.03, 0.22), mat=body, bevel=0.015)
    finalize_and_save("telephone.blend", 1.18)


def build_appareil():
    reset_scene()
    body = make_mat("CameraBlack", (0.14, 0.15, 0.19), roughness=0.48)
    silver = make_mat("CameraSilver", (0.82, 0.85, 0.90), metallic=0.85, roughness=0.22)
    lens = make_mat("CameraOptic", (0.15, 0.68, 0.95), metallic=0.5, roughness=0.06, emission=(0.10, 0.45, 0.80), emission_strength=0.8)
    red = make_mat("ShutterRed", (0.90, 0.14, 0.18), roughness=0.3)
    add_cube(loc=(0, 0, -0.04), scale=(0.92, 0.34, 0.56), mat=body, bevel=0.035)
    add_cube(loc=(0, 0, 0.22), scale=(0.93, 0.35, 0.12), mat=silver, bevel=0.02)
    add_cube(loc=(0, 0.02, 0.32), scale=(0.34, 0.28, 0.14), mat=silver, bevel=0.02)
    add_cyl(loc=(-0.28, 0, 0.31), r=0.065, depth=0.08, mat=red, verts=16)
    # Protruding camera lens
    add_cyl(loc=(0.04, -0.25, -0.02), r=0.25, depth=0.30, rot=(math.pi * 0.5, 0, 0), mat=silver, verts=28)
    add_torus(loc=(0.04, -0.39, -0.02), major_r=0.24, minor_r=0.03, rot=(math.pi * 0.5, 0, 0), mat=body, seg=28)
    add_sphere(loc=(0.04, -0.37, -0.02), scale=(0.21, 0.06, 0.21), mat=lens)
    finalize_and_save("appareil.blend", 1.15)


def build_microphone():
    reset_scene()
    mesh_m = make_mat("MicGrille", (0.84, 0.87, 0.92), metallic=0.88, roughness=0.28)
    body = make_mat("MicBody", (0.16, 0.18, 0.24), metallic=0.72, roughness=0.32)
    ring = make_mat("MicRedRing", (0.92, 0.16, 0.22), roughness=0.25, emission=(0.7, 0.08, 0.12), emission_strength=0.6)
    add_sphere(loc=(0, 0, 0.42), scale=(0.24, 0.24, 0.27), mat=mesh_m, seg=26, ring=18)
    add_torus(loc=(0, 0, 0.36), major_r=0.24, minor_r=0.028, mat=ring, seg=26)
    add_cone(loc=(0, 0, -0.14), r1=0.085, r2=0.145, depth=0.78, mat=body, verts=22)
    add_cyl(loc=(0, 0, -0.56), r=0.06, depth=0.12, mat=mesh_m, verts=16)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.38, orient_axis="Y")
    finalize_and_save("microphone.blend", 1.22)


def build_guitare():
    reset_scene()
    spruce = make_mat("GuitarWood", (0.84, 0.52, 0.18), roughness=0.32)
    neck_m = make_mat("MahoganyNeck", (0.32, 0.15, 0.07), roughness=0.48)
    hole_m = make_mat("SoundHole", (0.06, 0.05, 0.05), roughness=0.8)
    gold = make_mat("GuitarGold", (0.95, 0.80, 0.24), metallic=0.85, roughness=0.2)
    # Figure-8 acoustic body
    add_cyl(loc=(0, 0, -0.34), r=0.34, depth=0.14, rot=(math.pi * 0.5, 0, 0), mat=spruce, verts=28)
    add_cyl(loc=(0, 0, -0.05), r=0.25, depth=0.14, rot=(math.pi * 0.5, 0, 0), mat=spruce, verts=26)
    for sy in (-0.075, 0.075):
        add_cyl(loc=(0, sy, -0.10), r=0.10, depth=0.02, rot=(math.pi * 0.5, 0, 0), mat=hole_m, verts=22)
        add_torus(loc=(0, sy, -0.10), major_r=0.115, minor_r=0.015, rot=(math.pi * 0.5, 0, 0), mat=gold, seg=22)
        add_cube(loc=(0, sy, -0.36), scale=(0.22, 0.03, 0.055), mat=neck_m, bevel=0.005)
    # Long neck & headstock
    add_cube(loc=(0, 0, 0.42), scale=(0.09, 0.055, 0.68), mat=neck_m, bevel=0.008)
    add_cube(loc=(0, 0, 0.82), scale=(0.13, 0.05, 0.18), mat=neck_m, bevel=0.008)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=-0.36, orient_axis="Y")
    finalize_and_save("guitare.blend", 1.28)


# ==============================================================================
# SECTOR 8 (B1) — SANTÉ, URGENCES & SOCIÉTÉ
# ==============================================================================

def build_medicament():
    reset_scene()
    red = make_mat("CapsuleRed", (0.90, 0.11, 0.16), roughness=0.16)
    white = make_mat("CapsuleWhite", (0.96, 0.97, 0.99), roughness=0.18)
    band = make_mat("SilverBand", (0.82, 0.86, 0.92), metallic=0.8, roughness=0.2)
    # Upper red half capsule
    add_cyl(loc=(0, 0, 0.20), r=0.26, depth=0.40, mat=red, verts=28)
    add_sphere(loc=(0, 0, 0.40), scale=(0.26, 0.26, 0.26), mat=red, seg=28, ring=16)
    # Lower white half capsule
    add_cyl(loc=(0, 0, -0.20), r=0.252, depth=0.40, mat=white, verts=28)
    add_sphere(loc=(0, 0, -0.40), scale=(0.252, 0.252, 0.252), mat=white, seg=28, ring=16)
    add_torus(loc=(0, 0, 0.0), major_r=0.262, minor_r=0.018, mat=band, seg=28)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.62, orient_axis="Y")
    finalize_and_save("medicament.blend", 1.18)


def build_ambulance():
    reset_scene()
    white = make_mat("AmbWhite", (0.96, 0.97, 0.99), roughness=0.24)
    red = make_mat("CrossRed", (0.90, 0.11, 0.15), roughness=0.28)
    siren = make_mat("BlueSiren", (0.14, 0.58, 1.0), roughness=0.1, emission=(0.12, 0.55, 1.0), emission_strength=2.0)
    glass = make_mat("AmbGlass", (0.16, 0.28, 0.42), metallic=0.5, roughness=0.12)
    tire = make_mat("AmbTire", (0.10, 0.11, 0.14), roughness=0.75)
    add_cube(loc=(0.12, 0, 0.04), scale=(0.92, 0.56, 0.54), mat=white, bevel=0.035)
    add_cube(loc=(-0.44, 0, -0.06), scale=(0.34, 0.54, 0.34), mat=white, bevel=0.035)
    add_cube(loc=(-0.38, 0, 0.12), scale=(0.30, 0.50, 0.22), mat=glass, bevel=0.02)
    # Red stripe & Red Cross on both sides!
    add_cube(loc=(0.05, 0, -0.10), scale=(1.10, 0.575, 0.06), mat=red, bevel=0.005)
    for sy in (-0.288, 0.288):
        add_cube(loc=(0.18, sy, 0.10), scale=(0.24, 0.02, 0.075), mat=red, bevel=0.004)
        add_cube(loc=(0.18, sy, 0.10), scale=(0.075, 0.02, 0.24), mat=red, bevel=0.004)
    # Roof siren bar
    add_cube(loc=(-0.18, 0, 0.34), scale=(0.12, 0.38, 0.075), mat=siren, bevel=0.015)
    for wx in (-0.36, 0.36):
        for wy in (-0.28, 0.28):
            add_cyl(loc=(wx, wy, -0.23), r=0.13, depth=0.09, rot=(math.pi * 0.5, 0, 0), mat=tire, verts=18)
    finalize_and_save("ambulance.blend", 1.24)


def build_lettre():
    reset_scene()
    paper = make_mat("CreamPaper", (0.97, 0.94, 0.86), roughness=0.58)
    flap = make_mat("FlapShade", (0.90, 0.85, 0.74), roughness=0.60)
    wax = make_mat("WaxSeal", (0.86, 0.10, 0.14), roughness=0.28)
    stamp = make_mat("BlueStamp", (0.14, 0.42, 0.88), roughness=0.45)
    add_cube(loc=(0, 0, 0), scale=(1.04, 0.09, 0.68), mat=paper, bevel=0.02)
    for sy in (-0.05, 0.05):
        add_cone(loc=(0, sy, 0.12), r1=0.50, r2=0.02, depth=0.42, rot=(math.pi, 0, 0), scale=(1.0, 0.06, 1.0), mat=flap, verts=4, smooth=False)
        add_cyl(loc=(0, sy * 1.3, -0.03), r=0.11, depth=0.03, rot=(math.pi * 0.5, 0, 0), mat=wax, verts=20)
        add_cube(loc=(0.35, sy * 1.2, 0.20), scale=(0.14, 0.02, 0.17), mat=stamp, bevel=0.004)
    finalize_and_save("lettre.blend", 1.18)


def build_journal():
    reset_scene()
    news = make_mat("Newsprint", (0.93, 0.92, 0.88), roughness=0.70)
    ink = make_mat("DarkInk", (0.14, 0.16, 0.20), roughness=0.65)
    photo = make_mat("NewsPhoto", (0.18, 0.48, 0.84), roughness=0.5)
    add_cube(loc=(0, 0, 0), scale=(0.86, 0.14, 0.98), mat=news, bevel=0.03)
    add_cyl(loc=(-0.43, 0, 0), r=0.075, depth=0.98, mat=news, verts=16)
    for sy in (-0.075, 0.075):
        add_cube(loc=(0.02, sy, 0.34), scale=(0.68, 0.015, 0.11), mat=ink, bevel=0.003)
        add_cube(loc=(-0.14, sy, 0.06), scale=(0.34, 0.015, 0.30), mat=photo, bevel=0.003)
        for rz in (0.16, 0.04, -0.08, -0.22, -0.34):
            add_cube(loc=(0.20 if rz > -0.15 else 0.02, sy, rz), scale=(0.28 if rz > -0.15 else 0.66, 0.015, 0.045), mat=ink, bevel=0.002)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=0.35, orient_axis="X")
    finalize_and_save("journal.blend", 1.18)


def build_cadeau():
    reset_scene()
    box_m = make_mat("GiftTeal", (0.12, 0.72, 0.78), roughness=0.32)
    rib = make_mat("GiftRibbon", (0.92, 0.14, 0.24), metallic=0.25, roughness=0.25)
    gold = make_mat("BowCenter", (0.98, 0.82, 0.20), metallic=0.8, roughness=0.2)
    add_cube(loc=(0, 0, -0.12), scale=(0.74, 0.74, 0.66), mat=box_m, bevel=0.025)
    add_cube(loc=(0, 0, 0.18), scale=(0.80, 0.80, 0.14), mat=box_m, bevel=0.02)
    add_cube(loc=(0, 0, -0.08), scale=(0.82, 0.14, 0.76), mat=rib, bevel=0.01)
    add_cube(loc=(0, 0, -0.08), scale=(0.14, 0.82, 0.76), mat=rib, bevel=0.01)
    for ang in (0.0, math.pi * 0.5, math.pi * 0.25, -math.pi * 0.25):
        add_torus(loc=(0, 0, 0.34), major_r=0.16, minor_r=0.042, rot=(math.pi * 0.5, 0.35, ang), mat=rib, seg=20)
    add_sphere(loc=(0, 0, 0.30), scale=(0.08, 0.08, 0.08), mat=gold)
    finalize_and_save("cadeau.blend", 1.12)


# ==============================================================================
# SECTOR 9 (B1) — ENVIRONNEMENT, MÉTÉO & MONDE
# ==============================================================================

def build_arbre():
    reset_scene()
    trunk = make_mat("TreeTrunk", (0.44, 0.26, 0.12), roughness=0.72)
    leaf1 = make_mat("CanopyDark", (0.12, 0.56, 0.20), roughness=0.55)
    leaf2 = make_mat("CanopyBright", (0.20, 0.72, 0.26), roughness=0.50)
    add_cone(loc=(0, 0, -0.34), r1=0.16, r2=0.09, depth=0.66, mat=trunk, verts=16)
    add_sphere(loc=(0, 0, 0.10), scale=(0.48, 0.48, 0.36), mat=leaf1, seg=22, ring=14)
    add_sphere(loc=(-0.22, 0.12, 0.22), scale=(0.32, 0.32, 0.28), mat=leaf2, seg=20, ring=12)
    add_sphere(loc=(0.22, -0.10, 0.24), scale=(0.30, 0.30, 0.26), mat=leaf2, seg=20, ring=12)
    add_sphere(loc=(0, 0, 0.42), scale=(0.34, 0.34, 0.28), mat=leaf2, seg=20, ring=12)
    finalize_and_save("arbre.blend", 1.22)


def build_soleil():
    reset_scene()
    core = make_mat("SunCore", (1.0, 0.78, 0.12), roughness=0.2, emission=(1.0, 0.72, 0.08), emission_strength=2.0)
    ray_m = make_mat("SunRay", (1.0, 0.52, 0.08), roughness=0.25, emission=(1.0, 0.48, 0.06), emission_strength=1.4)
    add_sphere(loc=(0, 0, 0), scale=(0.40, 0.28, 0.40), mat=core, seg=28, ring=18)
    for i in range(12):
        ang = i * (2.0 * math.pi / 12.0)
        ln = 0.28 if i % 2 == 0 else 0.19
        r_mid = 0.48 + ln * 0.35
        add_cone(
            loc=(r_mid * math.sin(ang), 0, r_mid * math.cos(ang)),
            r1=0.085, r2=0.01, depth=ln,
            rot=(0, ang, 0), scale=(1.0, 0.45, 1.0), mat=ray_m, verts=10
        )
    finalize_and_save("soleil.blend", 1.22)


def build_nuage():
    reset_scene()
    cloud = make_mat("CloudWhite", (0.90, 0.94, 0.99), roughness=0.45)
    belly = make_mat("CloudSlate", (0.62, 0.72, 0.86), roughness=0.50)
    add_cube(loc=(0, 0, -0.16), scale=(0.92, 0.42, 0.18), mat=belly, bevel=0.08)
    puffs = [(-0.34, 0, -0.04, 0.26), (0.34, 0, -0.05, 0.25), (-0.12, 0.04, 0.12, 0.32), (0.18, -0.03, 0.08, 0.28), (0.0, 0, -0.02, 0.30)]
    for px, py, pz, pr in puffs:
        add_sphere(loc=(px, py, pz), scale=(pr * 1.15, pr * 0.85, pr), mat=cloud, seg=22, ring=14)
    finalize_and_save("nuage.blend", 1.22)


def build_usine():
    reset_scene()
    wall = make_mat("FactoryBrick", (0.68, 0.32, 0.24), roughness=0.65)
    roof = make_mat("SlateRoof", (0.24, 0.28, 0.35), metallic=0.4, roughness=0.45)
    stack = make_mat("ChimneyGrey", (0.76, 0.78, 0.82), roughness=0.55)
    red = make_mat("StackStripe", (0.88, 0.14, 0.18), roughness=0.4)
    win = make_mat("FactoryWin", (0.98, 0.84, 0.32), roughness=0.2, emission=(0.9, 0.75, 0.2), emission_strength=1.1)
    add_cube(loc=(-0.08, 0, -0.24), scale=(0.92, 0.56, 0.44), mat=wall, bevel=0.015)
    for rx in (-0.36, -0.08, 0.20):
        add_cone(loc=(rx, 0, 0.07), r1=0.18, r2=0.01, depth=0.22, scale=(1.0, 1.55, 1.0), mat=roof, verts=4, smooth=False)
    for sx in (0.22, 0.40):
        add_cone(loc=(sx, -0.12, 0.22), r1=0.085, r2=0.06, depth=0.72, mat=stack, verts=16)
        add_cyl(loc=(sx, -0.12, 0.46), r=0.066, depth=0.08, mat=red, verts=16)
    for wx in (-0.36, -0.14, 0.08):
        for sy in (-0.285, 0.285):
            add_cube(loc=(wx, sy, -0.22), scale=(0.13, 0.02, 0.16), mat=win, bevel=0.003)
    finalize_and_save("usine.blend", 1.22)


def build_globe():
    reset_scene()
    ocean = make_mat("EarthOcean", (0.10, 0.38, 0.86), roughness=0.28)
    land = make_mat("EarthLand", (0.18, 0.72, 0.30), roughness=0.45)
    brass = make_mat("GlobeStand", (0.90, 0.72, 0.20), metallic=0.85, roughness=0.22)
    add_sphere(loc=(0, 0, 0.08), scale=(0.42, 0.42, 0.42), mat=ocean, seg=28, ring=20)
    # Continent patches
    for lx, ly, lz, sc in [(0.16, -0.34, 0.20, 0.16), (-0.24, -0.30, 0.08, 0.18), (0.10, 0.35, 0.16, 0.19), (-0.18, 0.32, -0.05, 0.15)]:
        add_sphere(loc=(lx, ly, lz), scale=(sc, sc * 0.55, sc * 1.1), mat=land, seg=16, ring=12)
    add_torus(loc=(0, 0, 0.08), major_r=0.48, minor_r=0.026, rot=(math.pi * 0.5, 0.38, 0), mat=brass, seg=32)
    add_cyl(loc=(0, 0, -0.45), r=0.045, depth=0.22, mat=brass, verts=16)
    add_cone(loc=(0, 0, -0.56), r1=0.28, r2=0.08, depth=0.10, mat=brass, verts=24)
    finalize_and_save("globe.blend", 1.20)


# ==============================================================================
# GRAMMAR BREACH CRYSTAL + FPS WEAPON + ARENA PROPS
# ==============================================================================

def build_holo_crystal():
    """Glowing faceted hexagonal Data-Crystal for A2–B1 Grammar & Phonetic Breach Drones."""
    reset_scene()
    crystal = make_mat("GrammarCrystal", (0.58, 0.28, 1.0), metallic=0.25, roughness=0.12, emission=(0.48, 0.22, 0.98), emission_strength=1.8)
    gold = make_mat("DataRing", (0.98, 0.80, 0.22), metallic=0.88, roughness=0.18)
    add_cone(loc=(0, 0, 0.26), r1=0.28, r2=0.01, depth=0.52, mat=crystal, verts=6, smooth=False)
    add_cone(loc=(0, 0, -0.26), r1=0.28, r2=0.01, depth=0.52, rot=(math.pi, 0, 0), mat=crystal, verts=6, smooth=False)
    add_torus(loc=(0, 0, 0), major_r=0.44, minor_r=0.022, rot=(0.55, 0.35, 0), mat=gold, seg=28)
    add_torus(loc=(0, 0, 0), major_r=0.44, minor_r=0.022, rot=(-0.55, -0.35, 0), mat=gold, seg=28)
    finalize_and_save("holo_crystal.blend", 1.12)


def build_lit():
    reset_scene()
    wood = make_mat("BedWood", (0.48, 0.28, 0.14), roughness=0.78)
    sheet = make_mat("BedSheet", (0.95, 0.92, 0.86), roughness=0.82)
    blanket = make_mat("BedBlanket", (0.82, 0.28, 0.24), roughness=0.80)
    # Bed frame & headboard
    add_cube(loc=(0, 0, -0.08), scale=(0.92, 1.18, 0.14), mat=wood, bevel=0.02)
    add_cube(loc=(0, 0.54, 0.18), scale=(0.94, 0.10, 0.44), mat=wood, bevel=0.02)
    for sx in (-0.42, 0.42):
        for sy in (-0.52, 0.52):
            add_cyl(loc=(sx, sy, -0.22), r=0.05, depth=0.28, mat=wood, verts=12)
    # Mattress, pillow, blanket
    add_cube(loc=(0, -0.02, 0.04), scale=(0.84, 1.06, 0.16), mat=sheet, bevel=0.04)
    add_cube(loc=(0, -0.16, 0.06), scale=(0.86, 0.74, 0.17), mat=blanket, bevel=0.04)
    add_cube(loc=(0, 0.34, 0.15), scale=(0.56, 0.24, 0.10), mat=sheet, bevel=0.04)
    finalize_and_save("lit.blend", 1.24)


def build_lampe():
    reset_scene()
    brass = make_mat("LampBrass", (0.84, 0.64, 0.24), metallic=0.7, roughness=0.45)
    shade = make_mat("LampShade", (0.96, 0.86, 0.62), roughness=0.78, emission=(0.95, 0.80, 0.45), emission_strength=0.35)
    add_cyl(loc=(0, 0, -0.42), r=0.28, depth=0.08, mat=brass, verts=24)
    add_cyl(loc=(0, 0, -0.08), r=0.045, depth=0.64, mat=brass, verts=16)
    add_cone(loc=(0, 0, 0.26), r1=0.42, r2=0.22, depth=0.46, mat=shade, verts=26)
    finalize_and_save("lampe.blend", 1.22)


def build_blaster():
    reset_scene()
    walnut = make_mat("WalnutStock", (0.44, 0.24, 0.12), roughness=0.76)
    steel = make_mat("CharcoalBarrel", (0.22, 0.22, 0.24), metallic=0.60, roughness=0.48)
    brass = make_mat("BrassTrim", (0.88, 0.68, 0.24), metallic=0.75, roughness=0.42)
    ivory = make_mat("SightBead", (0.98, 0.94, 0.84), roughness=0.70)

    # Classic warm walnut & brushed brass sporting carbine
    add_cube(loc=(0, 0.02, -0.01), scale=(0.078, 0.42, 0.10), mat=walnut, bevel=0.020)
    add_cube(loc=(0, -0.22, -0.015), scale=(0.064, 0.34, 0.075), mat=walnut, bevel=0.016)
    # Matte charcoal barrel + brass barrel bands
    add_cyl(loc=(0, -0.26, 0.038), r=0.024, depth=0.68, rot=(math.pi * 0.5, 0, 0), mat=steel, verts=20)
    for by in (-0.12, -0.32, -0.52):
        add_cyl(loc=(0, by, 0.015), r=0.036, depth=0.024, rot=(math.pi * 0.5, 0, 0), mat=brass, verts=20)
    # Brass receiver side-plates & ring sight
    add_cube(loc=(0, 0.06, 0.02), scale=(0.084, 0.22, 0.065), mat=brass, bevel=0.010)
    add_torus(loc=(0, 0.04, 0.088), major_r=0.022, minor_r=0.004, rot=(math.pi * 0.5, 0, 0), mat=brass, seg=20)
    add_sphere(loc=(0, -0.56, 0.068), scale=(0.010, 0.010, 0.016), mat=ivory, seg=12, ring=8)
    # Walnut grip
    add_cube(loc=(0, 0.16, -0.10), scale=(0.062, 0.09, 0.18), rot=(-0.34, 0, 0), mat=walnut, bevel=0.015)
    finalize_and_save("blaster.blend", target_size=0.74, center_origin=False)


def build_drone():
    reset_scene()
    wood = make_mat("CarrierWood", (0.52, 0.32, 0.16), roughness=0.78)
    brass = make_mat("CarrierBrass", (0.86, 0.66, 0.22), metallic=0.70, roughness=0.45)
    cream = make_mat("PadCream", (0.96, 0.92, 0.82), roughness=0.80)
    red = make_mat("BullseyeRed", (0.84, 0.22, 0.18), roughness=0.78)
    add_cyl(loc=(0, 0, 0.0), r=0.48, depth=0.09, mat=wood, verts=28)
    add_torus(loc=(0, 0, 0.02), major_r=0.48, minor_r=0.035, mat=brass, seg=28)
    add_cyl(loc=(0, 0, 0.045), r=0.38, depth=0.03, mat=cream, verts=26)
    add_torus(loc=(0, 0, 0.06), major_r=0.26, minor_r=0.022, mat=red, seg=24)
    finalize_and_save("drone.blend", target_size=1.22, center_origin=True)


def build_pedestal():
    reset_scene()
    stone = make_mat("PedestalStone", (0.88, 0.82, 0.72), roughness=0.82)
    terra = make_mat("PedestalTerra", (0.78, 0.36, 0.24), roughness=0.78)
    brass = make_mat("PedestalBrass", (0.86, 0.68, 0.24), metallic=0.65, roughness=0.45)
    add_cyl(loc=(0, 0, 0.06), r=0.56, depth=0.12, mat=terra, verts=12, smooth=False)
    add_cone(loc=(0, 0, 0.52), r1=0.44, r2=0.36, depth=0.80, mat=stone, verts=12, smooth=False)
    add_cyl(loc=(0, 0, 0.95), r=0.44, depth=0.10, mat=terra, verts=12, smooth=False)
    add_cyl(loc=(0, 0, 1.01), r=0.34, depth=0.03, mat=brass, verts=24)
    finalize_and_save("pedestal.blend", target_size=1.15, center_origin=False)


def main():
    builders = [
        # Sectors 1-4 (A1)
        build_pomme, build_fromage, build_pain, build_bouteille, build_tasse,
        build_livre, build_cle, build_horloge, build_lanterne, build_lunettes,
        build_epee, build_bouclier, build_couronne, build_chapeau, build_marteau,
        build_fleur, build_coeur, build_poisson, build_etoile, build_fusee,
        # Sector 5 (A2 - Voyages)
        build_avion, build_train, build_voiture, build_velo, build_valise,
        # Sector 6 & 7 (A2 - Tech, Médias, Ville & Quotidien)
        build_ordinateur, build_telephone, build_appareil, build_microphone, build_batterie,
        build_parapluie, build_sac, build_chaussure, build_chaise, build_guitare,
        build_lit, build_lampe,
        # Sector 8 (B1 - Santé & Société)
        build_medicament, build_ambulance, build_lettre, build_journal, build_cadeau,
        # Sector 9 (B1 - Environnement & Monde)
        build_arbre, build_soleil, build_nuage, build_usine, build_globe,
        # Props & Weapons
        build_holo_crystal, build_blaster, build_drone, build_pedestal,
    ]
    for fn in builders:
        fn()
    print(f"SUCCESS: Generated {len(builders)} Blender 3D models in {OUT_DIR}")


if __name__ == "__main__":
    main()
