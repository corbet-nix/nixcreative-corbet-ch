# SPDX-License-Identifier: MIT OR Apache-2.0
# Reads the tier's promises back off the RENDERED BYTES, not off the options that produced them.
#
# The eval check proves the module resolves and refuses. This one proves the manifests that come
# out say what the module claims — which is a different question, and the only one a cluster ever
# sees. An option can be correct and the rendering still wrong.
{ pkgs, lib, nixidy, appsModule, clusterModule, values }:

let
  env = nixidy.lib.mkEnv {
    inherit pkgs;
    modules = [ appsModule clusterModule (import values) ];
  };
in
pkgs.runCommand "nixcreative-cluster-render"
{
  nativeBuildInputs = [ pkgs.yq-go ];
  manifests = env.environmentPackage;
} ''
  set -euo pipefail
  fail=0
  check() { # name expected actual
    if [ "$2" = "$3" ]; then echo "  ok   $1: $3"
    else echo "  FAIL $1: expected '$2', got '$3'"; fail=1; fi
  }
  y() { yq -r "$1" "$2"; }

  echo "== the environment renders every declared workload and nothing else =="
  rendered=$(ls "$manifests" | sort | tr '\n' ' ' | sed 's/ $//')
  check "rendered apps" "apps example-cloning example-graphs example-narration example-studio" "$rendered"

  graphs="$manifests/example-graphs/Deployment-example-graphs.yaml"
  studio="$manifests/example-studio/Deployment-example-studio.yaml"
  narration="$manifests/example-narration/Deployment-example-narration.yaml"
  cloning="$manifests/example-cloning/Deployment-example-cloning.yaml"

  echo "== the catalogue's port reaches every container, and no declaration stated one =="
  check "graphs port" "8188" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $graphs)"
  check "studio port" "8188" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $studio)"

  echo "== one card, one holder: durable directories AND a device mean the pod may not roll =="
  check "graphs strategy" "Recreate" "$(y '.spec.strategy.type' $graphs)"
  check "studio strategy" "Recreate" "$(y '.spec.strategy.type' $studio)"
  # An absent `replicas` IS one -- Kubernetes' own default. Asserting it is unset is the honest
  # form: the grammar deliberately stamps no count on a sleeping workload, because its count
  # belongs to whatever wakes it.
  check "graphs replicas unset (the wake front owns it)" "null" "$(y '.spec.replicas' $graphs)"
  check "studio replicas" "1" "$(y '.spec.replicas' $studio)"

  echo "== needing the card is visible in the bytes, and is requested exactly once per pod =="
  check "graphs gpu label" "true" "$(y '.metadata.labels."nixk3s.dev/gpu"' $graphs)"
  check "studio gpu label" "true" "$(y '.metadata.labels."nixk3s.dev/gpu"' $studio)"
  check "graphs containers" "1" "$(y '.spec.template.spec.containers | length' $graphs)"
  check "graphs device limit"   "1" "$(y '.spec.template.spec.containers[0].resources.limits."example.com/example-device"' $graphs)"
  check "graphs device request" "1" "$(y '.spec.template.spec.containers[0].resources.requests."example.com/example-device"' $graphs)"
  # The catalogue names no device and no count. Proving that means proving the string only ever
  # appears where the CONSUMER's own value put it -- so it must not be findable in this repository.
  check "device name absent from the catalogue" "0" \
    "$(grep -c 'example-device' ${../lib/applications.nix} || true)"

  echo "== a deployment's own sizing lands, and the catalogue supplied none of it =="
  check "graphs memory limit"   "2Gi" "$(y '.spec.template.spec.containers[0].resources.limits.memory' $graphs)"
  check "graphs memory request" "1Gi" "$(y '.spec.template.spec.containers[0].resources.requests.memory' $graphs)"
  check "studio memory limit"   "null" "$(y '.spec.template.spec.containers[0].resources.limits.memory' $studio)"
  # A CPU ceiling throttles rather than kills, so nothing here renders one unasked.
  check "graphs no cpu limit" "null" "$(y '.spec.template.spec.containers[0].resources.limits.cpu' $graphs)"

  echo "== the parent mount is emitted before the directory nested inside it =="
  check "graphs mount 0" "/root"                  "$(y '.spec.template.spec.containers[0].volumeMounts[0].mountPath' $graphs)"
  check "graphs mount 1" "/root/ComfyUI/models"   "$(y '.spec.template.spec.containers[0].volumeMounts[1].mountPath' $graphs)"
  check "graphs mount 2" "/images-out"            "$(y '.spec.template.spec.containers[0].volumeMounts[2].mountPath' $graphs)"

  echo "== what backs each directory is the declaration's half, and both backings render =="
  check "graphs weights path" "/example/weights" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .hostPath.path' $graphs)"
  # `Directory` refuses to start on a missing path. That is the whole guard: an auto-created model
  # directory is a workload that comes up healthy and can render nothing.
  check "graphs weights type" "Directory" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .hostPath.type' $graphs)"
  check "graphs home type" "DirectoryOrCreate" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "home") | .hostPath.type' $graphs)"
  check "studio weights claim" "example-weights" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .persistentVolumeClaim.claimName' $studio)"
  check "studio weights read-only" "true" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "models") | .readOnly' $studio)"

  echo "== the argument that routes the product still points at the directory that is backed =="
  # NOT `out`: that name is the derivation's own output path, and shadowing it here made this
  # check pass every assertion and then fail on `touch $out`.
  outmount=$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "output") | .mountPath' $graphs)
  cli=$(y '.spec.template.spec.containers[0].env[] | select(.name == "CLI_ARGS") | .value' $graphs)
  check "renders routed into the backed directory" "true" \
    "$(case "$cli" in *"--output-directory $outmount"*) echo true;; *) echo false;; esac)"
  echo "== and a card's own quirk arrives as the declaration's environment, never the catalogue's =="
  check "graphs card override" "0.0.0" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "HSA_OVERRIDE_GFX_VERSION") | .value' $graphs)"
  check "studio has no card override" "" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "HSA_OVERRIDE_GFX_VERSION") | .value' $studio)"

  echo "== the image is a tag when a version was given and a whole reference when one was =="
  check "graphs image" "yanwk/comfyui-boot:0.0.0" "$(y '.spec.template.spec.containers[0].image' $graphs)"
  check "studio digest-pinned" "true" "$(y '.spec.template.spec.containers[0].image' $studio | grep -q '@sha256:' && echo true || echo false)"

  echo "== the hook is a container and a volume this module BUILT, not one a declaration handed through =="
  # Every string below is derived. The catalogue holds the path and the directory it lives in and no
  # object name; the declaration holds an object name and an image and no path. A declaration that
  # could have written this container would be a passthrough, and none of these strings appears in
  # one.
  check "graphs init containers" "1" "$(y '.spec.template.spec.initContainers | length' $graphs)"
  check "graphs init name" "pre-start-install" "$(y '.spec.template.spec.initContainers[0].name' $graphs)"
  check "graphs init image is the declaration's" "true" \
    "$(y '.spec.template.spec.initContainers[0].image' $graphs | grep -q '^busybox:stable@sha256:' && echo true || echo false)"
  # COPIED AND MADE EXECUTABLE. The image runs `chmod +x` on this file before sourcing it, which is
  # what fails on the read-only projection a ConfigMap volume always is -- so the file has to land
  # on the writable directory as a plain file, which is why a container exists here at all.
  check "graphs init copies onto the catalogue's path" \
    "mkdir -p /root/user-scripts && cp /pre-start-src/pre-start.sh /root/user-scripts/pre-start.sh && chmod +x /root/user-scripts/pre-start.sh" \
    "$(y '.spec.template.spec.initContainers[0].command[2]' $graphs)"
  check "graphs init writes onto the durable directory" "/root" \
    "$(y '.spec.template.spec.initContainers[0].volumeMounts[] | select(.name == "home") | .mountPath' $graphs)"
  # The application's own container never reads the projection: only the container that installs
  # from it does, which is exactly the volume a null mountPath exists for.
  check "graphs app container does not mount the hook" "0" \
    "$(y '[.spec.template.spec.containers[0].volumeMounts[] | select(.name == "pre-start")] | length' $graphs)"
  check "graphs hook volume NAMES a ConfigMap" "example-pre-start" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "pre-start") | .configMap.name' $graphs)"
  # A name is not a payload. The same proof as the device name and the registry above: the object
  # name can only have come from the consumer, so it must not be findable in this repository.
  check "the ConfigMap name is absent from the catalogue" "0" \
    "$(grep -c 'example-pre-start' ${../lib/applications.nix} || true)"
  check "studio plants no hook" "null" "$(y '.spec.template.spec.initContainers' $studio)"

  echo "== a rename reaches the manifest and stops there =="
  check "studio renamed volume lands where the catalogue says" "/images-out" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "example-renders") | .mountPath' $studio)"
  check "studio carries no volume under the catalogue's key" "0" \
    "$(y '[.spec.template.spec.volumes[] | select(.name == "output")] | length' $studio)"
  check "and a workload that renames nothing keeps the catalogue's name" "/images-out" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "output") | .mountPath' $graphs)"

  echo "== fifteen minutes of tolerated start, and no guessed liveness probe =="
  check "graphs probe period"  "5"   "$(y '.spec.template.spec.containers[0].readinessProbe.periodSeconds' $graphs)"
  check "graphs probe budget"  "180" "$(y '.spec.template.spec.containers[0].readinessProbe.failureThreshold' $graphs)"
  check "graphs no liveness"   "null" "$(y '.spec.template.spec.containers[0].livenessProbe' $graphs)"
  check "studio no liveness"   "null" "$(y '.spec.template.spec.containers[0].livenessProbe' $studio)"

  echo "== no address is invented here: the Service is a plain ClusterIP with nothing pinned =="
  for f in $manifests/example-graphs/Service-example-graphs.yaml $manifests/example-studio/Service-example-studio.yaml; do
    check "$(basename $f) type" "ClusterIP" "$(y '.spec.type' $f)"
    check "$(basename $f) no pinned IP" "null" "$(y '.spec.clusterIP' $f)"
    check "$(basename $f) no nodePort" "null" "$(y '.spec.ports[0].nodePort' $f)"
  done

  # `-L` is load-bearing: the rendered tree is SYMLINKS into the store, so a plain `-type f`
  # matches nothing and returns a confident zero. A count that can only ever be zero is worse than
  # no check, because it passes the moment somebody expects zero.
  echo "== each namespace is anchored by exactly one workload, and the others join it =="
  check "namespaces rendered" "2" "$(find -L $manifests -name 'Namespace-*.yaml' -type f | wc -l)"
  check "which namespace"    "example-generative" \
    "$(y '.metadata.name' $manifests/example-graphs/Namespace-example-generative.yaml)"
  check "studio joined it"   "example-generative" "$(y '.metadata.namespace' $studio)"
  check "voice namespace"    "example-voice" \
    "$(y '.metadata.name' $manifests/example-narration/Namespace-example-voice.yaml)"
  check "cloning joined it"  "example-voice" "$(y '.metadata.namespace' $cloning)"

  echo "== THE AXIS THE TIER IS SPLIT ON, read off the bytes: one half asks for the device =="
  # This is the pair the whole two-workload split exists for. Everything else about them is alike --
  # an HTTP API, durable directories, no login -- and none of it would tell a scheduler which one is
  # the expensive one. An ABSENT label and an ABSENT resource are the assertion here: a catalogue
  # entry that quietly gained a device would render both of these as present.
  check "narration is not labelled a device tenant" "null" "$(y '.metadata.labels."nixk3s.dev/gpu"' $narration)"
  check "narration requests no device" "null" \
    "$(y '.spec.template.spec.containers[0].resources.requests."example.com/example-device"' $narration)"
  check "narration has no device ceiling" "null" \
    "$(y '.spec.template.spec.containers[0].resources.limits."example.com/example-device"' $narration)"
  check "cloning is labelled a device tenant" "true" "$(y '.metadata.labels."nixk3s.dev/gpu"' $cloning)"
  check "cloning requests the device once" "1" \
    "$(y '.spec.template.spec.containers[0].resources.requests."example.com/example-device"' $cloning)"
  check "cloning holds one container" "1" "$(y '.spec.template.spec.containers | length' $cloning)"
  # And the cheap half pays in what it actually costs, which is cores.
  check "narration asks for cores" "500m" \
    "$(y '.spec.template.spec.containers[0].resources.requests.cpu' $narration)"

  echo "== the catalogue supplies both voice ports, and neither declaration stated one =="
  check "narration port" "8880" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $narration)"
  check "cloning port"   "8004" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $cloning)"

  echo "== an application nobody publishes an image of gets its whole reference from the declaration =="
  check "cloning digest-pinned" "true" \
    "$(y '.spec.template.spec.containers[0].image' $cloning | grep -q '@sha256:' && echo true || echo false)"
  # The same proof as the device name above, for the same reason: the reference can only have come
  # from the consumer, so the registry must not be findable in this repository's catalogue.
  check "cloning registry absent from the catalogue" "0" \
    "$(grep -c 'registry.example.com' ${../lib/applications.nix} || true)"
  check "narration image is the catalogue's repository plus a version" "ghcr.io/remsky/kokoro-fastapi-cpu:0.0.0" \
    "$(y '.spec.template.spec.containers[0].image' $narration)"

  echo "== each probe is the one its own application needs, and neither guesses a liveness probe =="
  check "narration probe path"   "/health" "$(y '.spec.template.spec.containers[0].readinessProbe.httpGet.path' $narration)"
  check "narration probe period" "3"       "$(y '.spec.template.spec.containers[0].readinessProbe.periodSeconds' $narration)"
  check "narration probe budget" "60"      "$(y '.spec.template.spec.containers[0].readinessProbe.failureThreshold' $narration)"
  # NOT a health path: this server answers 404 there and 200 at the root once its model is loaded.
  check "cloning probe path"     "/"       "$(y '.spec.template.spec.containers[0].readinessProbe.httpGet.path' $cloning)"
  check "cloning probe budget"   "120"     "$(y '.spec.template.spec.containers[0].readinessProbe.failureThreshold' $cloning)"
  check "narration no liveness"  "null"    "$(y '.spec.template.spec.containers[0].livenessProbe' $narration)"
  check "cloning no liveness"    "null"    "$(y '.spec.template.spec.containers[0].livenessProbe' $cloning)"

  echo "== a card's quirk is the declaration's, and nothing is told where to write a product =="
  check "cloning card override" "0.0.0" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "HSA_OVERRIDE_GFX_VERSION") | .value' $cloning)"
  # Neither voice workload writes a product to disk -- audio leaves as the response to the request
  # that asked for it -- so there is no output argument to protect and none is invented.
  check "narration is told nothing at all" "null" "$(y '.spec.template.spec.containers[0].env' $narration)"
  check "narration has no command line"    "null" "$(y '.spec.template.spec.containers[0].args' $narration)"

  echo "== the directories the voice tier keeps, in the vocabulary the catalogue named =="
  check "narration mounts one directory" "1" "$(y '.spec.template.spec.containers[0].volumeMounts | length' $narration)"
  check "narration extra voices" "/app/api/src/models/extra" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[0].mountPath' $narration)"
  # Created when missing, and allowed to be: every released voice ships inside the image, so an
  # empty extra-voices directory is a deployment with no extra voices rather than a broken one.
  check "narration voices type" "DirectoryOrCreate" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "voices") | .hostPath.type' $narration)"
  check "cloning mounts three" "3" "$(y '.spec.template.spec.containers[0].volumeMounts | length' $cloning)"
  check "cloning cache"     "/app/hf_cache"       "$(y '.spec.template.spec.containers[0].volumeMounts[0].mountPath' $cloning)"
  check "cloning reference" "/app/reference_audio" "$(y '.spec.template.spec.containers[0].volumeMounts[1].mountPath' $cloning)"
  check "cloning voices"    "/app/voices"          "$(y '.spec.template.spec.containers[0].volumeMounts[2].mountPath' $cloning)"

  echo "== adoption is a term of the delivery object, and only the workload that claims it carries it =="
  # THE ONLY THING IN THIS MODULE THAT CHANGES THE APPLICATION RATHER THAN THE POD, which is why it
  # is read off the Application files and not the Deployments above. BOTH directions are asserted:
  # a term that renders something everywhere is indistinguishable from a term nothing reads.
  studio_app="$manifests/apps/Application-example-studio.yaml"
  graphs_app="$manifests/apps/Application-example-graphs.yaml"
  check "studio adopts: server-side apply" "ServerSideApply=true" \
    "$(y '.spec.syncPolicy.syncOptions[0]' $studio_app)"
  check "studio adopts: server-side diff" "ServerSideDiff=true" \
    "$(y '.metadata.annotations."argocd.argoproj.io/compare-options"' $studio_app)"
  # An ABSENT syncOptions and an ABSENT annotation. A default that quietly started rendering would
  # put every workload on server-side apply, which on a live cluster is a diff nobody asked for.
  check "graphs does not adopt: no sync option" "null" "$(y '.spec.syncPolicy.syncOptions' $graphs_app)"
  check "graphs does not adopt: no compare option" "null" "$(y '.metadata.annotations' $graphs_app)"
  check "the voice tier does not adopt either" "null" \
    "$(y '.spec.syncPolicy.syncOptions' $manifests/apps/Application-example-narration.yaml)"

  echo "== sleeping is the device tenant's, and the resident half keeps its replica =="
  check "cloning replicas unset (the wake front owns it)" "null" "$(y '.spec.replicas' $cloning)"
  check "narration replicas" "1" "$(y '.spec.replicas' $narration)"

  if [ "$fail" -ne 0 ]; then
    echo "rendered output does not match the tier's promises" >&2
    exit 1
  fi
  echo "nixcreative: the rendered tree matches every promise asserted here"
  touch $out
''
