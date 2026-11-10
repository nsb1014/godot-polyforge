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

# Required anatomy close-ups: actual imported geometry, with front/back grip views.
scene.render.resolution_x=700;scene.render.resolution_y=700
for suffix,subject in [('L','right'),('R','left')]:
 hand=next(o for o in scene.objects if o.type=='MESH' and o.name=='hand_'+suffix)
 target=sum((hand.matrix_world@Vector(v) for v in hand.bound_box),Vector())/8
 data.ortho_scale=1.15
 for label,offset in [('front',(0,-4,.4)),('back',(0,4,.4))]:
  camera.location=target+Vector(offset)
  camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=f'{ROOT}/renders/hand_{subject}_{label}.png'
  bpy.ops.render.render(write_still=True)
data.ortho_scale=2.1
target=Vector((0,0,3.40*.9))
for label,offset in [('front',(0,-5,.4)),('side',(5,0,.4)),('top',(0,-.1,5))]:
 camera.location=target+Vector(offset)
 camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=f'{ROOT}/renders/horns_{label}.png'
 bpy.ops.render.render(write_still=True)

# Isolated, hand-local diagnostics supplement the assembled context views above.
def godot_point(v):
 return Vector((v[0],-v[2],v[1]))
shaft_axis=Vector((2.63,1.54,0)).normalized()
for suffix,subject,t,elbow in [('L','right',.24,(-1.01,2.12,.18)),('R','left',.70,(1.02,2.26,.20))]:
 grip=Vector((-1.03,1.40,.67)).lerp(Vector((1.60,2.94,.67)),t)
 toward=Vector(elbow)-grip
 normal=(toward-shaft_axis*toward.dot(shaft_axis)).normalized()
 target=godot_point((grip+normal*.10)*.9)
 for o in scene.objects:
  if o.type=='MESH':
   o.hide_render=not (o.name in ['hand_'+suffix,'thumb_'+suffix,'axe_shaft'] or o.name.startswith('finger_'+suffix+'_') or o.name.startswith('axe_wrap_'))
 data.ortho_scale=.8
 for label,sign in [('palm',-1),('back',1)]:
  camera.location=target+godot_point(normal)*sign*4+godot_point(shaft_axis)*.8
  camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=f'{ROOT}/renders/hand_{subject}_{label}_isolated.png'
  bpy.ops.render.render(write_still=True)
for o in scene.objects:
 o.hide_render=False
