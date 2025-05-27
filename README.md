# OpenStreetMap replication diff search tool

## Usage

This tool is designed to help you find the state file for a specific diff in OpenStreetMap replication. It can be used to search for diffs by minute, hour, or day stored on the <https://planet.osm.org> server as well as any other server that follows the same replication system.

This is a stateless tool, meaning it does not store any data between runs. It is designed to be run in a single command, and it will output the state file for the specified diff.

```sh
./osm-diff-state.sh <period> <timestamp> [replication_url] [options]
```

To use the tool, you need to specify the following parameters:

- \<period>: The period for which you want to find the state file. This can be either "minute", "hour", or "day".
  - `minute`: means you want to find the state file for a specific minute.
  - `hour`: means you want to find the state file for a specific hour.
  - `day`: means you want to find the state file for a specific day.
- \<timestamp>: The timestamp for which you want to find the state file. This should be in the format "`YYYY-MM-DD[<T|␣>HH[:MM[:SS]]][Z]`". The timestamp should be in UTC time.
- `replication_url`: (optional, default <https://planet.osm.org/replication/>) The URL of the replication server. This should be in the format "<https://download.openstreetmap.fr/replication/europe/poland/lodzkie/minute/>".
- options:
  - `--osm-like[=<true|false>]`: (optional, default true) If this flag is set, the tool will use the OSM-like URL format for the replication server. This is useful if you are using a server that does not follow the standard replication system.
  - `--help|-h`: (optional) If this flag is set, the tool will display the help message and exit.
  - `--log-level=<level>`: (optional, default "info") Set the log level for the tool. The available levels are "debug", "info", "warning", "error", and "fatal". This can be useful for debugging or for getting more information about the tool's operation.
  - `--verbose|-v`: (optional) Verbose is an equivalent to `--log-level=debug`. It will output more information about the tool's operation.
  - `--quiet|-q`: (optional) Quiet is an equivalent to `--log-level=error`. It will suppress all output except for errors. This can be useful if you only want to see error messages and nothing else.

## Example

Simple request for a state file for a specific day that is stored on the default planet OSM server:

```bash
./osm-diff-state.sh day "2025-05-16"
```

```log
[2025-05-27 09:52:07] INFO: Script parameters - Period: day, Timestamp: 2025-05-16
[2025-05-27 09:52:07] INFO: Using URL: https://planet.osm.org/replication/
[2025-05-27 09:52:07] INFO: Parsing and preparing base URL
[2025-05-27 09:52:07] INFO: URL parsing completed successfully: 'https://planet.osm.org/replication/' -> 'https://planet.osm.org/replication/day/'
[2025-05-27 09:52:07] INFO: Effective base URL: https://planet.osm.org/replication/day/
[2025-05-27 09:52:07] INFO: Checking URL accessibility: https://planet.osm.org/replication/day/
[2025-05-27 09:52:07] INFO: Fetching latest sequence number from: https://planet.osm.org/replication/day/state.txt
[2025-05-27 09:52:07] INFO: Fetching latest timestamp from: https://planet.osm.org/replication/day/state.txt
[2025-05-27 09:52:08] INFO: Starting binary search with bounds: [4629, 4640]
[2025-05-27 09:52:09] INFO: Binary search found sequence number: 4629
[2025-05-27 09:52:10] INFO: Final result URL: https://planet.osm.org/replication/day/000/004/629.state.txt
https://planet.osm.org/replication/day/000/004/629.state.txt
```

Example with explicit URL that is following the OSM-like URL format:

```bash
./osm-diff-state.sh hour "2025-05-16T12:00" "https://planet.osm.org/replication/" --osm-like=true
```

Request to a custom server that does not follow the OSM-like URL format:

```bash
./osm-diff-state.sh hour "2025-05-16 12:00:00" "https://custom.osm.server/osm/hour-diffs/" --osm-like=false
```

Request for a state file for a specific minute that is stored on the custom server that does follow the OSM-like URL format using shortened parameter `--osm-like`:

```bash
./osm-diff-state.sh minute "2025-05-16 12:15:45" https://download.openstreetmap.fr/replication/europe/poland/lodzkie/minute/ --osm-like
```

## Run with Docker

This repository contains a Dockerfile that can be used to build a Docker image for the OSM Diff tool. This image can be run in a container, allowing you to run the tool in an isolated environment without needing to install any dependencies on your local machine. More information see in [README.Docker.md](README.Docker.md).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

OpenStreetMap is a registered trademark of the OpenStreetMap Foundation. This project is not affiliated with or endorsed by the OpenStreetMap Foundation.
