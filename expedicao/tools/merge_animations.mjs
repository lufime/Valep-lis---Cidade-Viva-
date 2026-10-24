import { NodeIO } from '@gltf-transform/core';
import { KHRONOS_EXTENSIONS } from '@gltf-transform/extensions';
import fs from 'node:fs/promises';

const io = new NodeIO().registerExtensions(KHRONOS_EXTENSIONS);

function copyAccessor(targetDoc, source) {
  const array = source.getArray();
  const accessor = targetDoc.createAccessor()
    .setType(source.getType())
    .setNormalized(source.getNormalized());
  if (array) accessor.setArray(array.slice());
  return accessor;
}

async function merge(characterPath, outputPath, animationPaths) {
  const characterDoc = await io.read(characterPath);
  const characterRoot = characterDoc.getRoot();
  const nodesByName = new Map();
  for (const node of characterRoot.listNodes()) {
    if (node.getName()) nodesByName.set(node.getName(), node);
  }
  let totalChannels = 0;
  let totalClips = 0;
  for (const animationPath of animationPaths) {
    const animationDoc = await io.read(animationPath);
    const animationRoot = animationDoc.getRoot();
    const nodeMap = new Map();
    for (const node of animationRoot.listNodes()) {
      const name = node.getName();
      if (name && nodesByName.has(name)) nodeMap.set(node, nodesByName.get(name));
    }
    console.log(`ANIMATION_RIG_MATCH | nodes=${nodeMap.size}`);
    if (nodeMap.size < 40) throw new Error(`Rig incompatível: apenas ${nodeMap.size} nós coincidentes.`);
    for (const animation of animationRoot.listAnimations()) {
      const merged = characterDoc.createAnimation(animation.getName());
      let clipChannels = 0;
      for (const channel of animation.listChannels()) {
        const target = nodeMap.get(channel.getTargetNode());
        const sampler = channel.getSampler();
        if (!target || !sampler?.getInput() || !sampler?.getOutput()) continue;
        const input = copyAccessor(characterDoc, sampler.getInput());
        const output = copyAccessor(characterDoc, sampler.getOutput());
        const newSampler = characterDoc.createAnimationSampler()
          .setInput(input).setOutput(output).setInterpolation(sampler.getInterpolation());
        merged.addSampler(newSampler).addChannel(characterDoc.createAnimationChannel()
          .setTargetNode(target).setTargetPath(channel.getTargetPath()).setSampler(newSampler));
        clipChannels++;
      }
      if (clipChannels > 0) {
        totalChannels += clipChannels;
        totalClips++;
      } else {
        characterDoc.getRoot().listAnimations().pop();
      }
    }
  }
  if (totalClips < 5 || totalChannels < 100) {
    throw new Error(`Poucas animações aplicadas: clips=${totalClips}, canais=${totalChannels}`);
  }
  const bytes = await io.writeBinary(characterDoc);
  await fs.writeFile(outputPath, bytes);
  console.log(`ANIMATION_MERGE_PASS | clips=${totalClips} channels=${totalChannels} bytes=${bytes.byteLength}`);
}

const [, , characterPath, outputPath, ...animationPaths] = process.argv;
if (!characterPath || !outputPath || animationPaths.length === 0) {
  console.error('Usage: node merge_animations.mjs character.glb output.glb animation.glb [...]');
  process.exit(2);
}
merge(characterPath, outputPath, animationPaths).catch(error => {
  console.error('ANIMATION_MERGE_FAIL |', error);
  process.exit(1);
});
