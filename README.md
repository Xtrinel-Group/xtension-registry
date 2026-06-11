<p align="center">
  <img src="https://assets.xtrinel.com/xtension-logo.svg" alt="Xtension Registry" width="320" />
</p>

# Xtension Registry

The community plugin registry for VAAST Xtensions. This repository powers the Xtension marketplace at [xtension.xtrinel.com](https://xtension.xtrinel.com).

## How it works

Xtensions are submitted as JSON manifest files via pull request. On merge, all manifests are compiled into `registry.json` and published to CDN.

- `registry/official/` — Xtensions maintained by Xtrinel
- `registry/community/` — Xtensions contributed by the community

## Publishing an Xtension

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full submission guide.

## Schema

The manifest schema is defined in `schema/manifest.schema.json`. Validate locally:

```bash
npx ajv-cli validate -s schema/manifest.schema.json -d registry/community/your-id.json --spec=draft7 -c ajv-formats
```

## Links

- [Xtension Marketplace](https://xtension.xtrinel.com)
- [VAAST](https://xtrinel.com/vaast)
- [Xtrinel](https://xtrinel.com)
