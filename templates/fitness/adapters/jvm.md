# Adapter — JVM (ArchUnit)

[ArchUnit](https://github.com/TNG/ArchUnit) is "a free, simple and extensible library
for checking the architecture of your Java code." It analyzes compiled bytecode and
lets you assert structural rules **inside your normal test suite** — "check
dependencies between packages and classes, layers and slices, check for cyclic
dependencies and more," using any plain JUnit runner. Works for Java and Kotlin.

Enforces tier-1 intents: **dependency direction**, **no cycles**, **layering** — and
because the rules are tests, a violation fails CI exactly like any failing test.

## Install (Maven)

```xml
<dependency>
  <groupId>com.tngtech.archunit</groupId>
  <artifactId>archunit-junit5</artifactId>
  <version>1.3.0</version>
  <scope>test</scope>
</dependency>
```

Gradle: `testImplementation 'com.tngtech.archunit:archunit-junit5:1.3.0'`.

## Rules that encode the intents

```java
@AnalyzeClasses(packages = "com.example.app")
class ArchitectureTest {

  @ArchTest
  static final ArchRule domain_does_not_depend_on_adapters =
      noClasses().that().resideInAPackage("..domain..")
          .should().dependOnClassesThat().resideInAPackage("..adapter..");
      // Tier-1 intent: dependency direction.

  @ArchTest
  static final ArchRule no_cycles =
      slices().matching("com.example.app.(*)..")
          .should().beFreeOfCycles();
      // Tier-1 intent: no new cycles.

  @ArchTest
  static final ArchRule layering =
      layeredArchitecture().consideringAllDependencies()
          .layer("Web").definedBy("..web..")
          .layer("Service").definedBy("..service..")
          .layer("Persistence").definedBy("..persistence..")
          .whereLayer("Web").mayNotBeAccessedByAnyLayer()
          .whereLayer("Persistence").mayOnlyBeAccessedByLayers("Service");
      // Tier-1 intent: layering / ownership.
}
```

## Run in CI

Nothing special — these run in `mvn test` / `gradle test`. A broken architecture rule
is a red test. Wire the same test task into the pre-push hook template.
