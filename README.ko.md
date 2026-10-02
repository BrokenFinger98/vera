<!-- translated-from: README.md@initial -->
# Vera

> *vera* — 라틴어로 "진실한". ServiceNow 같은 기록 시스템이 어떻게 하나의 플랫폼 바이너리를 유지하면서
> 고객마다 커스터마이징을 허용하는지 이해하기 위해 직접 만드는 메타데이터 기반 엔터프라이즈 플랫폼 엔진.

Vera는 학습·포트폴리오 프로젝트입니다. 플랫폼 층(런타임에 정의되는 테이블/필드의 메타데이터 엔진, 샌드박스
스크립트 룰 엔진, 표준과 고객 수정분을 분리하는 레이어링/업그레이드 엔진, 나중에 멀티 인스턴스 프로비저닝)을
먼저 만들고, 그 위에 IT 자산관리(ITAM) 앱을 올립니다.

**이 저장소의 모든 코드는 AI 코딩 에이전트가 작성합니다.** 소유자는 티켓마다 세 번 승인합니다(미리보기, 설계 리뷰,
머지). 큰 기능은 스펙도 승인합니다. 코드·테스트·문서는 모두 에이전트가 작성합니다. 방식은 `CLAUDE.md`와
`docs/superpowers/specs/`에 있습니다.

## 상태

Phase 0 — 저장소·툴체인·하네스 구축 단계. `.harness/state/progress.md` 참고.

## 빌드

JDK 25와 Docker(통합 테스트)가 필요합니다.

```bash
./scripts/check.sh   # 포맷 검사, detekt, 유닛 테스트, 아키텍처 테스트
./scripts/itest.sh   # 통합 테스트 (Testcontainers PostgreSQL 18)
./scripts/build.sh   # 빌드(assemble)
```

데모 스택: `docker compose up -d` 후 `SPRING_PROFILES_ACTIVE=dev ./gradlew :bootstrap:bootRun`.
저장소 루트에서 실행하세요. IDE 실행 구성도 작업 디렉터리를 루트로 두어야 `compose.yml`을 찾습니다.

## 스택

Kotlin 2.3 · Java 25 · Spring Boot 4.1 · Spring Modulith 2.1 · PostgreSQL 18 · jOOQ 3.21 ·
Flyway · GraalJS(룰 샌드박스) · Testcontainers 2 · Gradle 9.7.

## 라이선스

MIT. 커밋되는 산출물(코드·커밋·문서)은 영어입니다. 이 파일만 한국어 쌍입니다.
