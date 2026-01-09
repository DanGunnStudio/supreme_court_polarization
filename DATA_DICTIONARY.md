# Data Dictionary

## Supreme Court Database (SCDB) - Justice-Centered Data

**Source**: Washington University Law - Supreme Court Database  
**Version**: 2024 Release 01  
**File**: `SCDB_2024_01_justiceCentered_Citation.Rdata`  
**URL**: http://scdb.wustl.edu/data.php

---

## Dataset Overview

| Property | Value |
|----------|-------|
| Rows | 83,068 |
| Columns | 61 |
| Time Period | 1946-2023 |
| Unique Cases | 9,277 |
| Unique Justices | 40 |

---

## Variable Definitions

### Identifiers

| Variable | Type | Description |
|----------|------|-------------|
| `caseId` | character | Unique case identifier (format: YYYY-NNN) |
| `docketId` | character | Docket identifier |
| `caseIssuesId` | character | Case-issues identifier |
| `voteId` | character | Unique vote identifier |

### Date Variables

| Variable | Type | Description |
|----------|------|-------------|
| `dateDecision` | Date | Date of decision |
| `dateArgument` | Date | Date of oral argument |
| `dateRearg` | Date | Date of reargument (if applicable) |
| `term` | integer | Supreme Court term year (1946-2023) |

### Case Information

| Variable | Type | Description |
|----------|------|-------------|
| `caseName` | character | Full case name |
| `docket` | character | Docket number |
| `chief` | character | Chief Justice at time of decision |
| `naturalCourt` | integer | Natural court identifier |

### Citation Variables

| Variable | Type | Description |
|----------|------|-------------|
| `usCite` | character | United States Reports citation |
| `sctCite` | character | Supreme Court Reporter citation |
| `ledCite` | character | Lawyers' Edition citation |
| `lexisCite` | character | LexisNexis citation |

### Party Information

| Variable | Type | Description |
|----------|------|-------------|
| `petitioner` | integer | Petitioner category code |
| `petitionerState` | integer | Petitioner state code (if applicable) |
| `respondent` | integer | Respondent category code |
| `respondentState` | integer | Respondent state code (if applicable) |

### Procedural Variables

| Variable | Type | Description |
|----------|------|-------------|
| `jurisdiction` | integer | Basis for Supreme Court jurisdiction |
| `adminAction` | integer | Administrative action code |
| `adminActionState` | integer | Administrative action state |
| `threeJudgeFdc` | integer | Three-judge federal district court (0/1) |
| `caseOrigin` | integer | Court of origin code |
| `caseOriginState` | integer | State of court of origin |
| `caseSource` | integer | Court source code |
| `caseSourceState` | integer | State of court source |
| `certReason` | integer | Reason for granting certiorari |

### Lower Court Variables

| Variable | Type | Description |
|----------|------|-------------|
| `lcDisagreement` | integer | Lower court disagreement (0/1) |
| `lcDisposition` | integer | Lower court disposition |
| `lcDispositionDirection` | integer | Lower court disposition direction |

### Decision Variables

| Variable | Type | Description |
|----------|------|-------------|
| `decisionType` | integer | Type of decision (see codes below) |
| `caseDisposition` | integer | Case disposition (see codes below) |
| `caseDispositionUnusual` | integer | Unusual disposition flag |
| `declarationUncon` | integer | Declaration of unconstitutionality |
| `partyWinning` | integer | Which party won (see codes below) |
| `precedentAlteration` | integer | Whether precedent was altered |
| `voteUnclear` | integer | Vote unclear flag |

### Issue Variables

| Variable | Type | Description |
|----------|------|-------------|
| `issue` | integer | Specific legal issue code |
| `issueArea` | integer | Broad issue area (see codes below) |

### Direction Variables

| Variable | Type | Description |
|----------|------|-------------|
| `decisionDirection` | integer | Ideological direction of decision |
| `decisionDirectionDissent` | integer | Direction of dissent |

### Legal Authority Variables

| Variable | Type | Description |
|----------|------|-------------|
| `authorityDecision1` | integer | Primary legal authority |
| `authorityDecision2` | integer | Secondary legal authority |
| `lawType` | integer | Type of law involved |
| `lawSupp` | integer | Supplemental law code |
| `lawMinor` | character | Minor law description |

### Opinion Variables

| Variable | Type | Description |
|----------|------|-------------|
| `majOpinWriter` | integer | Justice who wrote majority opinion |
| `majOpinAssigner` | integer | Justice who assigned majority opinion |
| `splitVote` | integer | Whether vote was split |

### Vote Count Variables

| Variable | Type | Description | Range |
|----------|------|-------------|-------|
| `majVotes` | integer | Number of votes in majority | 3-9 |
| `minVotes` | integer | Number of votes in minority | 0-4 |

### Justice-Level Variables

| Variable | Type | Description |
|----------|------|-------------|
| `justice` | integer | Justice identifier number |
| `justiceName` | character | Justice name abbreviation |
| `vote` | integer | How the justice voted (see codes below) |
| `opinion` | integer | Opinion type written (see codes below) |
| `direction` | integer | Ideological direction of vote (see codes below) |
| `majority` | integer | Whether in majority (see codes below) |
| `firstAgreement` | integer | First agreement code |
| `secondAgreement` | integer | Second agreement code |

---

## Code Values

### Vote Codes (`vote`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Voted with majority | 58,402 |
| 2 | Dissented | 14,224 |
| 3 | Regular concurrence | 3,143 |
| 4 | Special concurrence | 3,677 |
| 5 | Judgment of the Court | 258 |
| 6 | Dissent from denial of certiorari | 20 |
| 7 | Jurisdictional dissent | 393 |
| 8 | Did not participate | 924 |
| NA | Missing | 2,027 |

### Direction Codes (`direction`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | **Conservative** | 37,141 |
| 2 | **Liberal** | 41,195 |
| NA | Unspecifiable | 4,732 |

### Majority Codes (`majority`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Dissent (minority) | 14,617 |
| 2 | Majority | 65,480 |
| NA | Missing | 2,971 |

### Decision Type Codes (`decisionType`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Opinion of the court (orally argued) | 65,124 |
| 2 | Per curiam (orally argued) | 8,910 |
| 4 | Decrees | 590 |
| 5 | Equally divided vote | 1,033 |
| 6 | Per curiam (not orally argued) | 5,127 |
| 7 | Judgment of the Court (orally argued) | 2,284 |

### Issue Area Codes (`issueArea`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Criminal Procedure | 18,710 |
| 2 | Civil Rights | 13,486 |
| 3 | First Amendment | 6,303 |
| 4 | Due Process | 3,216 |
| 5 | Privacy | 1,095 |
| 6 | Attorneys | 924 |
| 7 | Unions | 3,328 |
| 8 | Economic Activity | 16,299 |
| 9 | Judicial Power | 11,262 |
| 10 | Federalism | 3,742 |
| 11 | Interstate Relations | 942 |
| 12 | Federal Taxation | 2,854 |
| 13 | Miscellaneous | 269 |
| 14 | Private Action | 63 |

### Decision Direction Codes (`decisionDirection`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Conservative | 39,791 |
| 2 | Liberal | 41,429 |
| 3 | Unspecifiable | 1,471 |

### Party Winning Codes (`partyWinning`)

| Code | Description | Count |
|------|-------------|-------|
| 0 | Petitioner lost | 29,621 |
| 1 | Petitioner won | 53,222 |
| 2 | Unclear | 63 |

### Opinion Codes (`opinion`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | No opinion or not available | 61,572 |
| 2 | Wrote opinion | 18,784 |
| 3 | Joined opinion | 676 |

### Case Disposition Codes (`caseDisposition`)

| Code | Description | Count |
|------|-------------|-------|
| 1 | Stay, petition, or motion granted | 439 |
| 2 | Affirmed | 24,599 |
| 3 | Reversed | 18,044 |
| 4 | Reversed and remanded | 22,556 |
| 5 | Vacated and remanded | 10,360 |
| 6 | Affirmed and reversed in part | 683 |
| 7 | Affirmed and reversed in part and remanded | 1,526 |
| 8 | Vacated | 303 |
| 9 | Petition denied or appeal dismissed | 3,222 |
| 10 | Certification | 116 |
| 11 | No disposition | 9 |

---

## Justices (1946-2023)

| Abbreviation | Full Name | Tenure |
|--------------|-----------|--------|
| ACBarrett | Amy Coney Barrett | 2020-present |
| AFortas | Abe Fortas | 1965-1969 |
| AJGoldberg | Arthur Goldberg | 1962-1965 |
| AMKennedy | Anthony Kennedy | 1988-2018 |
| AScalia | Antonin Scalia | 1986-2016 |
| BMKavanaugh | Brett Kavanaugh | 2018-present |
| BRWhite | Byron White | 1962-1993 |
| CEWhittaker | Charles Whittaker | 1957-1962 |
| CThomas | Clarence Thomas | 1991-present |
| DHSouter | David Souter | 1990-2009 |
| EKagan | Elena Kagan | 2010-present |
| EWarren | Earl Warren | 1953-1969 |
| FFrankfurter | Felix Frankfurter | 1939-1962 |
| FMVinson | Fred Vinson | 1946-1953 |
| FMurphy | Frank Murphy | 1940-1949 |
| HABlackmun | Harry Blackmun | 1970-1994 |
| HHBurton | Harold Burton | 1945-1958 |
| HLBlack | Hugo Black | 1937-1971 |
| JGRoberts | John Roberts | 2005-present |
| JHarlan2 | John Marshall Harlan II | 1955-1971 |
| JPStevens | John Paul Stevens | 1975-2010 |
| KBJackson | Ketanji Brown Jackson | 2022-present |
| LFPowell | Lewis Powell | 1972-1987 |
| NMGorsuch | Neil Gorsuch | 2017-present |
| PStewart | Potter Stewart | 1958-1981 |
| RBGinsburg | Ruth Bader Ginsburg | 1993-2020 |
| RHJackson | Robert Jackson | 1941-1954 |
| SAAlito | Samuel Alito | 2006-present |
| SDOConnor | Sandra Day O'Connor | 1981-2006 |
| SFReed | Stanley Reed | 1938-1957 |
| SGBreyer | Stephen Breyer | 1994-2022 |
| SMinton | Sherman Minton | 1949-1956 |
| SSotomayor | Sonia Sotomayor | 2009-present |
| TCClark | Tom Clark | 1949-1967 |
| TMarshall | Thurgood Marshall | 1967-1991 |
| WBRutledge | Wiley Rutledge | 1943-1949 |
| WEBurger | Warren Burger | 1969-1986 |
| WHRehnquist | William Rehnquist | 1972-2005 |
| WJBrennan | William Brennan | 1956-1990 |
| WODouglas | William O. Douglas | 1939-1975 |

---

## Key Computed Variables (Project-Specific)

These variables are computed in `SupremeCourt.qmd`:

| Variable | Formula | Description |
|----------|---------|-------------|
| `year` | `year(dateDecision)` | Year extracted from decision date |
| `agreement_percentage` | `majVotes / (majVotes + minVotes) * 100` | Percentage of justices in majority |
| `agreement_rate` | Pairwise calculation | How often two justices vote together |
| `AgreementVariance` | `var(Agreement)` by year | Polarization metric (higher = more polarized) |

---

## Citation

Harold J. Spaeth, Lee Epstein, Andrew D. Martin, Jeffrey A. Segal, Theodore J. Ruger, and Sara C. Benesh. 2024 Supreme Court Database, Version 2024 Release 01. URL: http://supremecourtdatabase.org

---

## Related Documentation

- **Codebook**: `raw_data/SCDB_2024_01_codebook.pdf`
- **Online Documentation**: http://scdb.wustl.edu/documentation.php
