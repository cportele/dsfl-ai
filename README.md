# dsfl-ai

Configuration of the OGC APIs and MCP servers published at https://bag.ldproxy.net, built with
[ldproxy](https://github.com/interactive-instruments/ldproxy). It is part of the work in the project
"Towards an AI-ready data space Physical Living Environment for the Netherlands" (Data Space
Fysieke Leefomgeving, DSFL).

The repository is an ldproxy data directory together with a database dump and a Docker Compose
setup to run it locally.

| API | Content | Source |
|-----|---------|--------|
| `/bag` | Basisregistratie Adressen en Gebouwen (BAG), with history | Kadaster, BAG 2.0 Extract |
| `/bgt` | Basisregistratie Grootschalige Topografie (BGT), with history | PDOK, BGT extract (CityGML) |
| `/wijkenbuurten` | Gemeenten, wijken and buurten 2026 | CBS, Wijk- en Buurtkaart 2026 |
| `/postcode6` | Statistics per postcode area (PC6) 2024 | CBS, Postcode6 2024 |
| `/dso` | Workflows (Arazzo) on the rules of the Omgevingswet at an address | DSO APIs (live) and `/bag` |

Every API is also available as an MCP server at `/{api}/mcp`. The database dump in `db/dump`
covers the gemeente Amersfoort.

The Arazzo workflows of `/dso` in `values/workflows/dso` are unofficial, edited versions of
workflows of the DSO team, for testing in the DSFL AI project. Official workflows are planned to be
published in the future at https://developer.omgevingswet.overheid.nl/dso/dso/digitaal-stelsel/.
The changes are noted at the top of each file.

## Running locally

Requirements: Docker with Docker Compose. The configuration needs ldproxy features that are not
released yet (building blocks for MCP, versioned features, processes and Arazzo workflows);
`docker-compose.yml` therefore uses the image `iide/ldproxy:aird` from Docker Hub (amd64 and
arm64). The tag `aird` follows the development; the tags `aird-<yymmddHHMMSS>` stay fixed and can
be selected with `LDPROXY_IMAGE`.

```sh
# optional, a fixed version of the image
export LDPROXY_IMAGE=iide/ldproxy:aird-<yymmddHHMMSS>
# optional, only for /dso: API keys of the Digitaal Stelsel Omgevingswet
export DSO_APIKEY=<key> DSO_IHRAPIKEY=<key>
docker compose up -d
```

On the first start the database container restores the dump into `db/data`, and ldproxy starts
once the database is ready. The APIs are then available at http://localhost:7080, for example
http://localhost:7080/bag.

Instead of the exports, the variables can be set in a file `.env` next to `docker-compose.yml`,
which Docker Compose reads automatically; keep it out of version control. The database account and
password are `bag`/`bag` by default, which is meant for local use only; other values are set with
`BAG_DB_USER` and `BAG_DB_PASSWORD`. PostgreSQL applies them only on the first start, when
`db/data` is empty.

```sh
# .env
BAG_DB_USER=<account>
BAG_DB_PASSWORD=<password>
DSO_APIKEY=<key>
DSO_IHRAPIKEY=<key>
```

## Using the MCP servers

Every API is an MCP server at `https://bag.ldproxy.net/{api}/mcp` (Streamable HTTP, no
authentication), with `{api}` one of `bag`, `bgt`, `wijkenbuurten`, `postcode6` and `dso`. The
servers describe their tools and give instructions on how to use them. For example, in Claude Code:

```sh
for api in bag bgt wijkenbuurten postcode6 dso; do
  claude mcp add --transport http --scope user $api https://bag.ldproxy.net/$api/mcp
done
```

In Claude Desktop and claude.ai, add them as custom connectors.

## Layout

- `cfg.yml`: ldproxy configuration
- `entities/`: feature providers (`providers/`) and APIs (`services/`)
- `values/`: codelists, stored queries, processes and Arazzo workflows
- `db/dump`: PostgreSQL dump (pg_dump directory format, Git LFS)
- `docker/`, `docker-compose.yml`: local setup

Files marked `generated - do not edit` are generated from the source data and catalogues; changes
to them are made in the generator.

## Licence

The configuration in this repository is licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), see [LICENSE](LICENSE), except for the
edited copies of the DSO workflows (`values/workflows/dso/*.yaml` other than `bag-adres.yaml`),
which are not covered by this licence.

The data in `db/dump` is subject to the licences of its sources:

- BAG: Kadaster, Basisregistratie Adressen en Gebouwen, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
- BGT: Basisregistratie Grootschalige Topografie, PDOK, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
- Wijken en buurten: © Centraal Bureau voor de Statistiek (CBS), Wijk- en Buurtkaart 2026, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Postcode6: © CBS, © ESRI Nederland, CBS Postcode6 2024, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
