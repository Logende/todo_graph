/// A function that returns "now". Injected wherever wall-clock time would
/// otherwise be read directly, so tests can pin time deterministically.
typedef Clock = DateTime Function();
