### Version-Level index.json Schema

```json
{
  "pname": "serde",
  "version": "1.0.215",
  "language": "rust",
  "hash": "sha256:04xwh16jm7szizkkhj637jv23i5x8jnzcfrw6bfsrssqkjykaxcm",
  "github": {
    "owner": "serde-rs",
    "repo": "serde",
    "rev": "v1.0.215",
    "hash": "sha256:0qaz2mclr5cv3s5riag6aj3n3avirirnbi7sxpq4nw1vzrq09j6l"
  },
  "lastBuild": "2025-11-28T12:00:00Z",
  "buildDuration": 342150,
  "processors": {
    "build": { "active": true, "published": false, "buildDuration": 251755 },
    "docs": { "active": true, "published": true, "buildDuration": 45230, "fileCount": 142, "fileSize": 2458624, "hash": "sha256:..." },
    "types": { "active": true, "published": true, "buildDuration": 12045, "fileCount": 1, "fileSize": 48320, "hash": "sha256:..." },
    "api-surface": { "active": true, "published": true, "buildDuration": 28100, "fileCount": 1, "fileSize": 15872, "hash": "sha256:..." },
    "repo": { "active": true, "published": true, "buildDuration": 5020, "fileCount": 89, "fileSize": 1245184, "hash": "sha256:..." }
  }
}
```

**Field Descriptions**:
- `buildDuration`: Integer - Duration in milliseconds (omitted if `active: false`)
- `processors.[name].active`: Boolean - Whether processor was executed
- `processors.[name].published`: Boolean - Whether output was copied to repository
- `processors.[name].fileCount`: Integer - Number of published files (omitted if `published: false`)
- `processors.[name].fileSize`: Integer - Total size of published files in bytes (omitted if `published: false`)
- `processors.[name].hash`: String - SHA256 of the result of this directory (omitted if `published: false`)

### Version-Level README.md Template

```markdown
# serde v1.0.228

**Language**: Rust
**Last Build**: 2025-11-28T12:00:00Z
**Build Duration**: 5m 42.15s

## Processors

| Processor | Active | Published | Duration | Files | Size | 
|-----------|--------|-----------|----------|-------|------|
| Build | ✓ | - | 4m 11.76s | - | - |
| Documentation | [view output](./documentation/) | ✓ | 45.23s | 142 | 2.34 MB |
| Foo | ✓ | [view output](./foo/) | 12.05s | 1 | 47.19 KB |
| Bar | ✓ | [view output](./bar/) | 28.10s | 1 | 15.50 KB |
