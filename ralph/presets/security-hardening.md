---
name: Security Hardening
description: Comprehensive adversarial security audit and hardening of the entire repository
category: Security
priority: 5
tags: [security, audit, hardening, vulnerabilities]
---

# Security Hardening Specification

## Objective

Perform a complete, adversarial security audit and hardening of the entire repository. Assume all external input is malicious and that attackers will attempt to exploit every boundary, dependency, and trust relationship.

## Security Mindset

- **Zero trust** - Verify everything, trust nothing
- **Defense in depth** - Multiple layers of protection
- **Fail secure** - Errors should deny access, not grant it
- **Least privilege** - Minimum necessary permissions everywhere
- **No security through obscurity** - Assume attackers know the code

## Phase 1: Security Assessment

### 1.1 Attack Surface Mapping

1. **Identify all entry points**
   - API endpoints
   - User inputs (forms, URLs, headers, cookies)
   - File uploads
   - WebSocket connections
   - CLI arguments
   - Environment variables

2. **Map trust boundaries**
   - Client/server boundaries
   - Internal/external service calls
   - Database access layers
   - Third-party integrations

3. **Review authentication flows**
   - Login mechanisms
   - Session management
   - Token handling
   - Password reset flows

### 1.2 Vulnerability Categories to Address

#### Injection Flaws
- SQL injection
- NoSQL injection
- Command injection
- LDAP injection
- XPath injection
- Expression Language injection

#### Cross-Site Scripting (XSS)
- Reflected XSS
- Stored XSS
- DOM-based XSS

#### Authentication & Session
- Broken authentication
- Session fixation
- Credential stuffing protection
- Brute force protection

#### Authorization
- Insecure direct object references (IDOR)
- Privilege escalation (horizontal & vertical)
- Missing function-level access control

#### Data Protection
- Sensitive data exposure
- Insecure cryptography
- Missing encryption at rest/transit
- Information leakage in errors/logs

#### Configuration & Infrastructure
- Security misconfiguration
- Missing security headers
- CORS misconfigurations
- Exposed debug endpoints
- Default credentials

## Phase 2: Remediation

### 2.1 Input Validation & Sanitization

- Implement **strict input validation** on all external data
- Use **allowlist-based validation** (not blocklist)
- Apply **schema enforcement** for structured data
- Use **parameterized queries** for all database operations
- Apply **context-appropriate output encoding** for all rendered content

### 2.2 Authentication & Authorization

- Enforce **strong password policies** via proper key derivation (bcrypt, argon2, scrypt)
- Implement **secure session management**
- Use **constant-time comparisons** for all secret comparisons
- Apply **deny-by-default** authorization
- Implement **per-resource authorization checks**

### 2.3 Cryptography

- Replace custom/weak crypto with **modern, vetted libraries**
- Use **secure random number generators**
- Implement proper **key management**
- Ensure **TLS everywhere** for network communication

### 2.4 Secret Management

- **Remove all secrets from code and history** where possible
- Implement **secure secret loading** (environment, vault, etc.)
- Ensure **no sensitive data in logs or error messages**
- Review **git history for leaked credentials**

### 2.5 Network Security

- Implement **SSRF protections** - block internal/metadata addresses
- Add **strict timeouts** on all external requests
- Enforce **size limits** on requests and responses
- Validate **all remote responses**

### 2.6 File Security

- Prevent **path traversal** attacks
- Validate **file types and sizes**
- Isolate **uploaded files from execution**
- Remove **unsafe file handling logic**

### 2.7 Dependency Security

- **Update all dependencies** to supported versions
- **Remove unused dependencies**
- **Enable automated dependency scanning**
- **Fix or mitigate** all known vulnerabilities

### 2.8 Security Headers & Configuration

- Implement **Content-Security-Policy**
- Add **X-Content-Type-Options: nosniff**
- Enable **X-Frame-Options** or frame-ancestors
- Configure **Strict-Transport-Security**
- Set **secure cookie attributes**

## Phase 3: Verification

### 3.1 Automated Checks

- Run **static analysis** tools
- Execute **dependency vulnerability scans**
- Perform **secret scanning**
- Validate **security header configuration**

### 3.2 Security Regression Tests

- Add tests that **verify fixed vulnerabilities cannot recur**
- Test **authentication bypass attempts**
- Test **authorization boundary enforcement**
- Test **input validation edge cases**

## Deliverables

- [ ] All identified vulnerabilities fixed or mitigated
- [ ] Security headers properly configured
- [ ] Dependencies updated and vulnerabilities resolved
- [ ] Secrets removed from codebase
- [ ] Security regression tests added
- [ ] Documentation updated with security considerations
- [ ] Summary of security improvements in progress.txt

## Constraints

- **No backward compatibility** - Security takes priority
- **No fallbacks or debug endpoints** - Remove all bypass mechanisms
- **No weakened controls** - Fix properly or remove feature
- **Build must succeed** with zero high/critical security issues

## Success Criteria

- All automated security scans pass with no high/critical findings
- All tests pass including new security tests
- No secrets in codebase or accessible in git history
- Proper authentication and authorization on all protected resources
- All user input properly validated and sanitized
