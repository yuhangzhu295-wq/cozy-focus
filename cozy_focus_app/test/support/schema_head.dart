/// The schema version the app declares, in one place.
///
/// ## Why this is a constant rather than a literal in each test
///
/// Every migration test has to assert that the chain *reached the head* rather
/// than stopping part way, which means each one names the head version. When the
/// literal lived in six files, adding a migration broke six tests and the fix was
/// six edits that could each be done wrong — which is exactly what happened in
/// P2, P3 and P4. One constant, and a guard test that it matches the database
/// class, means a new migration updates one line and cannot drift.
library;

const int kSchemaHead = 10;
