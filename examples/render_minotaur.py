import bpy, math, os, sys
from pathlib import Path
from mathutils import Vector
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ROOT = str(Path(args[0] if args else 'out/minotaur').resolve())
os.makedirs(ROOT + '/renders', exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ROOT+'/minotaur.glb')
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=40
scene.cycles.use_denoising=False
scene.render.threads_mode='FIXED'
scene.render.threads=8
scene.world=bpy.data.worlds.new('Studio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.26,.32,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
# Blender's glTF importer maps Godot Y-up to Blender Z-up.
points=[o.matrix_world@Vector(v) for o in scene.objects if o.type=='MESH' for v in o.bound_box]
low=Vector(tuple(min(v[i] for v in points) for i in range(3)))
high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
center=(low+high)/2
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.015))
floor=bpy.context.object
mat=bpy.data.materials.new('Warm gray floor');mat.diffuse_color=(.16,.18,.21,1);mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.16,.18,.21,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
floor.data.materials.append(mat)
def light(name,loc,power,size,color):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
 o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc
 o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-4,-6,7),1000,5,(1,.83,.66))
light('Fill',(4,-3,5),750,4,(.66,.80,1))
light('Rim',(1,4,6),1400,3,(.72,.83,1))
data=bpy.data.cameras.new('Review camera');camera=bpy.data.objects.new('Review camera',data)
scene.collection.objects.link(camera);scene.camera=camera;data.type='ORTHO';data.ortho_scale=4.65
scene.render.resolution_x=600;scene.render.resolution_y=680;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
for angle in [0,45,90,135,180,225,270,315]:
 a=math.radians(angle)
 camera.location=center+Vector((8*math.sin(a),-8*math.cos(a),1.35))
 camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=f'{ROOT}/renders/view_{angle:03d}.png'
 bpy.ops.render.render(write_still=True)
# Keep a reusable native scene at the primary three-quarter camera.
a=math.radians(15);camera.location=center+Vector((8*math.sin(a),-8*math.cos(a),.9))
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1000;scene.render.resolution_y=1100
scene.render.filepath=f'{ROOT}/minotaur_preview.png'
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/minotaur_review.blend')
bpy.ops.render.render(write_still=True)
