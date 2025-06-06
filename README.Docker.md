# Run with Docker

This repository contains a Dockerfile that can be used to build a Docker image for the OSM Diff tool. This image can be run in a container, allowing you to run the tool in an isolated environment without needing to install any dependencies on your local machine.

## Build the Docker Image

First, build your image, e.g.: `docker build -t osm-diff-state .`. If your cloud uses a different CPU architecture than your development machine (e.g., you are on a Mac M1 and your cloud provider is amd64), you'll want to build the image for that platform, e.g.: `docker build --platform=linux/amd64 -t osm-diff-state .`.

## Publish the Docker Image (Optional)

Then, push it to your registry, e.g. `docker push myregistry.com/osm-diff-state`.

Consult Docker's [getting started](https://docs.docker.com/go/get-started-sharing/) docs for more detail on building and pushing.

## Using pre-built Docker Images

If you prefer not to build the Docker image yourself, you can use the pre-built images (amd64 or arm64) available on [Docker Hub](https://hub.docker.com/r/andygol/osm-diff-state) or [GitHub Container Registry](https://github.com/users/Andygol/packages/container/package/osm-diff-state).

- For Docker Hub, you can pull the image using:

  ```bash
  docker pull osm-diff-state:latest
  ```

- For GitHub Container Registry, you can pull the image using:

  ```bash
  docker pull ghcr.io/andygol/osm-diff-state:latest
  ```

## Run the Docker Container

To run the Docker container, use (for example) the following command:

```bash
docker run --rm -it ghcr.io/andygol/osm-diff-state:latest minute "2025-05-16 00:00:00" https://download.openstreetmap.fr/replication/europe/poland/lodzkie/minute/ --osm-like=false
```

This command will run the `osm-diff-state` tool in a Docker container, using the specified parameters to get state file for a diff for the given minute.

For more information on how to use the tool, see the [README.md](README.md) file.
