# For the Kingdom 

## Installation
```bash
pnpm install
```

## Generate tables
```bash
pnpm mud tablegen
```

## Build
```bash
pnpm build
```

## Test
```bash
pnpm test
```

## Deploy
1. Update PRIVATE_KEY in .env
2. Update (or add) `cache = false` into `foundry.toml` under [profile.default]
```bash
pnpm deploy:testnet
```
