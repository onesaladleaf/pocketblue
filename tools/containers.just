[private]
pull-image image:
    #!/usr/bin/env bash
    set -xeuo pipefail

    # retry 3 times
    n=0
    until [ "$n" -ge 3 ]; do
        podman pull {{image}} && break
        n=$((n+1))
        sleep 10
    done

    if [ "$n" -ge 3 ]; then
        exit 1
    fi

[private]
pull-pocketblue:
    #!/usr/bin/env bash
    set -xeuo pipefail

    if skopeo inspect docker://{{full_image}} >/dev/null 2>&1; then
        just pull-image {{full_image}}
    elif skopeo inspect docker://{{fallback_image}} >/dev/null 2>&1; then
        # to rechunk new branches correctly
        just pull-image {{fallback_image}}
        podman tag {{fallback_image}} {{full_image}}
    else
        echo "::warning::Could not find a baseline image for rechunking"
    fi

[parallel]
pull: (pull-image base) pull-pocketblue

build *ARGS:
    buildah bud \
        --layers=true \
        --arch="{{arch}}" \
        --build-arg="base={{base}}" \
        --build-arg="device={{device}}" \
        --build-arg="desktop={{desktop}}" \
        --build-arg="target_tag={{tag}}" \
        {{ARGS}} \
        -t "{{full_image}}{{rechunk_suffix}}" \
        {{ if expires_after != "" { "--label quay.expires-after=" + expires_after } else { "" } }} \
        "."

rechunk *ARGS:
    podman run --rm --privileged -v /var/lib/containers:/var/lib/containers {{ARGS}} \
        {{base}} \
        rpm-ostree experimental compose build-chunked-oci \
            --bootc \
            --format-version=1 \
            --max-layers=127 \
            --from={{full_image}}{{rechunk_suffix}} \
            --output=containers-storage:{{full_image}}

build-chunkah *ARGS:
    #!/usr/bin/env bash
    set -xeuo pipefail

    CHUNKAH_CONFIG_STR=$(podman inspect {{full_image}}) || CHUNKAH_CONFIG_STR=
    buildah bud \
        --layers=true \
        --skip-unused-stages=false \
        --arch="{{arch}}" \
        --build-arg="base={{base}}" \
        --build-arg="device={{device}}" \
        --build-arg="desktop={{desktop}}" \
        --build-arg="target_tag={{tag}}" \
        --build-arg="CHUNKAH_CONFIG_STR=${CHUNKAH_CONFIG_STR}" \
        -v=$(pwd):/run/src \
        --security-opt=label=disable \
        {{ if expires_after != "" { "--label quay.expires-after=" + expires_after } else { "" } }} \
        {{ARGS}} \
        -t "{{full_image}}" \
        -f Containerfile.chunkah.in \
        "."
    [ -d out ] && rm -r out/

sign digest:
    cosign sign -y --new-bundle-format=false --key env://SIGNING_KEY "{{registry}}/{{device}}-{{desktop}}@{{digest}}"

rebase:
    rpm-ostree rebase ostree-unverified-image:containers-storage:{{full_image}}

bootc *ARGS:
    podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v .:/data \
        --security-opt label=type:unconfined_t \
        "{{full_image}}" bootc {{ARGS}}
