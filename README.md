# 🌱 Seed Vault Registry

## Overview

**Seed Vault Registry** is a blockchain-based system for farmers and agricultural institutions to register, verify, and track crop genetics on-chain. Built on the Stacks blockchain using Clarity smart contracts, this decentralized registry provides cryptographic proof of genetic authenticity, creates immutable lineage records, and enables secure seed vault management.

### 🎯 Value Proposition

- **For Farmers**: Protect intellectual property of rare/heirloom varieties, prove genetic authenticity for premium pricing
- **For Gene Banks**: Create tamper-proof preservation records, track genetic diversity and conservation efforts  
- **For Agricultural Research**: Enable transparent lineage tracking and genetic verification across breeding programs
- **For Supply Chain**: Provide immutable provenance records from seed to harvest

## 🔧 Core Features

### Genetic Registration System
- **Seed Fingerprinting**: Store cryptographic hashes of genetic markers
- **Batch Management**: Group seeds by harvest season, location, and variety
- **Farmer Attribution**: Link genetic material to verified farmers/institutions

### Vault Security & Access Control
- **Locking Mechanism**: Prevent unauthorized modifications to registered genetics
- **Owner-Only Access**: Ensure only vault owners can modify or unlock their records
- **Permission Management**: Grant/revoke access to specific genetic records

### Lineage & Provenance Tracking
- **Parent-Child Relationships**: Record breeding history and genetic crosses
- **Multi-Generation Tracking**: Trace genetic heritage across multiple breeding cycles
- **Quality Verification**: Validate genetic authenticity against stored fingerprints

## 🏗️ Smart Contract Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Seed Vault Registry                      │
├─────────────────────────────────────────────────────────────┤
│  🔐 seed-vault-registry.clar                               │
│   ├─ register-seed(fingerprint, farmer, batch-id)          │
│   ├─ lock-vault(seed-id) / unlock-vault(seed-id)           │
│   ├─ record-lineage(child-id, parent-ids)                  │
│   ├─ get-seed-info(seed-id) -> {owner, locked, lineage}    │
│   └─ list-seeds-by-farmer(farmer) -> [seed-ids...]         │
├─────────────────────────────────────────────────────────────┤
│  ✅ genetic-verification.clar                               │
│   ├─ verify-genetics(seed-id, provided-hash) -> (ok bool)  │
│   ├─ add-genetic-marker(seed-id, marker-hash)              │
│   ├─ get-verification-status(seed-id) -> verified?         │
│   └─ update-quality-score(seed-id, score)                  │
└─────────────────────────────────────────────────────────────┘

   Data Storage Maps:
   ├─ seed-registry: {seed-id -> {fingerprint, owner, locked, batch-id}}
   ├─ lineage-records: {seed-id -> [parent-seed-ids...]}  
   ├─ genetic-markers: {seed-id -> [marker-hashes...]}
   └─ verification-log: {seed-id -> {verified, quality-score, timestamp}}
```

## 🛠️ Prerequisites

- **Node.js** ≥18.0.0
- **Clarinet** (Stacks smart contract development tool)
- **GitHub CLI** (for repository management)
- **Git** (version control)

### Installation

```bash
# Install Clarinet
brew install hirosystems/tap/clarinet

# Install GitHub CLI
brew install gh

# Verify installations
clarinet --version
gh --version
node --version
```

## 🚀 Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/godiyasmith7-web/seed-vault-registry.git
cd seed-vault-registry
npm install
```

### 2. Run Tests

```bash
# Validate Clarity syntax
clarinet check

# Run contract unit tests  
clarinet test

# Run Node-based integration tests
npm test
```

### 3. Development Workflow

```bash
# Create new contract
clarinet contract new my-contract

# Check all contracts
clarinet check

# Interactive console for testing
clarinet console
```

### 4. Local Development

```bash
# Start local devnet
clarinet integrate

# Deploy contracts to local testnet
clarinet deploy --testnet
```

## 📋 Usage Examples

### Register New Seed Variety

```clarity
;; Register heirloom tomato genetics
(contract-call? .seed-vault-registry register-seed 
  0x1a2b3c4d5e6f7890abcdef1234567890  ;; genetic fingerprint hash
  'ST1FARMER123...                     ;; farmer's principal
  u20240101)                          ;; batch ID (YYYYMMDD format)
```

### Lock Vault for Security

```clarity
;; Protect seed record from unauthorized changes
(contract-call? .seed-vault-registry lock-vault u12345)
```

### Record Breeding Lineage

```clarity
;; Document cross-breeding between two parent varieties
(contract-call? .seed-vault-registry record-lineage 
  u67890                              ;; new hybrid seed ID
  (list u12345 u54321))              ;; parent seed IDs
```

### Verify Genetic Authenticity

```clarity
;; Validate seed matches registered genetics
(contract-call? .genetic-verification verify-genetics
  u12345                              ;; seed ID to verify
  0x1a2b3c4d5e6f7890abcdef1234567890) ;; provided genetic hash
```

## 🔒 Security & Privacy

- **Cryptographic Hashing**: Genetic data stored as irreversible SHA-256 hashes
- **Access Control**: Multi-level permissions (owner, authorized users, read-only)
- **Audit Trail**: Immutable history of all genetic modifications and verifications
- **Privacy Protection**: No raw genetic data stored on-chain, only fingerprints

## 🤝 Contributing

### Branching Model
- `main` → Production-ready code
- `development` → Integration branch for features
- `feature/*` → Individual feature development
- `hotfix/*` → Critical bug fixes

### Commit Conventions

```
feat: add new genetic verification endpoint
fix: resolve vault locking race condition  
docs: update README with usage examples
test: add integration tests for lineage tracking
chore: update dependencies and tooling
```

### Pull Request Process

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'feat: add amazing feature'`
4. Push branch: `git push origin feature/amazing-feature`  
5. Open pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Stacks Foundation** for blockchain infrastructure
- **Hiro Systems** for Clarinet development tools
- **Agricultural Research Community** for domain expertise
- **Open Source Contributors** worldwide

---

**Built with ❤️ for sustainable agriculture and food security**

*Protecting genetic heritage, one seed at a time.*
