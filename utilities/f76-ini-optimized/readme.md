
This file is an optimized fallout 76 ini to help frame rate and choppiness.

Copy the contents of the file, overwrite contents in `Documents\My Games\Fallout 76\Fallout76Prefs.ini`


# Changes

Shadows — the biggest FPS killer in this game.

fShadowDistance/fDirShadowDistance: 120000 > 6000. iShadowMapResolution: 2048 > 1024. uiShadowFilter/uiOrthoShadowFilter: 3 > 1. iMaxFocusShadows/iMaxFocusShadowsDialogue: 4 > 1. iDirShadowSplits: 4 > 2. uPointLightShadowMapMaxResLog2: 10 > 8. fMaxFocusShadowMapDistance: 450 > 200.

Post-processing / lighting effects — turned off, minimal visual loss.

bVolumetricLightingEnable, bSAOEnable, bScreenSpaceReflections, bMBEnable (motion blur), bDoDepthOfField, bLensFlare, bScreenSpaceBokeh, bEffectShaderAllowPBRShadows > 0. uWaterShadowFilter, iVolumetricLightingTextureQuality > 0.

Decals: iMaxDecalsPerFrame 100>25, iMaxSkinDecalsPerFrame 25>6, uMaxDecals 250>75, uMaxSkinDecals 50>15.

Draw distances (TerrainManager/Grass): all cut roughly 50-60% — block distances, tree load distance, grass fade distances.

LOD: fade-out multipliers increased (objects pop to lower detail sooner).

Water: hi-res, displacements, refractions, reflections all off; depth kept on.

Texture: mip-skip flags enabled (1), iTextureQualityLevel 3>2, so it streams slightly lower-res textures under load instead of stuttering.

Misc: uFaceGenTextureResolution 1024>512, iRainOcclusionMapResolution 512>256, iMaxAnisotropy 16>8, iParticles.iMaxDesired 750>300, sAntiAliasing TAA>FXAA (much cheaper, slightly less smooth edges), bClientEnableIntenseLightEffects 1>0.

Untouched: FOV, uGridsToLoad (lowering this below 5 can break world streaming), iPresentInterval (already 0/vsync off), all HUD colors, controls, audio, and gameplay toggles.