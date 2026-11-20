# ADR-003: Lamp fuel and dawn objective

## Status

Implemented in the current simulation. Automated regression covers core fuel, relight, drain, dawn, scoring, and older pickup/hit behavior. Hidden Phase 1–2 suites have not been run.

## Decision

Represent fuel as integer sixtieths (`_fuel_units`) to avoid drift at 60 ticks/second. A bright lamp loses one unit per second; each draining shade consumes five more. A lamp turns off at zero and retains `ever_lit`. Re-lighting costs five motes. The night no longer ends early when all lamps are lit: each night resolves at dawn using the 60% threshold, with no-flames loss taking precedence.

## Test impact

Replace early-win assertions with a no-early-win check and dawn threshold cases. Keep old pickup, movement, pulse, and collision tests if not superseded. Update the score expectations to the Phase 3 formula and document each changed expectation.
