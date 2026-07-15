# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Understand the dependency before replacing it

Before introducing a double, trace the real dependency's contract, state changes,
errors, ordering, and other side effects. Identify which of those effects the test's
claim actually depends on. A high-level mock that removes a required write, cache
update, event, or lifecycle transition can make the test pass or fail for the wrong
reason.

Prefer the real implementation when it is fast and deterministic. Otherwise replace
the narrowest slow, nondeterministic, or external boundary while preserving the
behavior owned by the layer under test. If that behavior is not yet understood, run
a bounded observation with the real dependency before choosing the double.

## Keep doubles faithful to the real contract

A double need not reproduce every implementation detail, but it must not contradict
the real interface or the semantics exercised by the test. Build response data from
an authoritative schema, contract, recorded fixture, or owner-maintained builder
when available. Include every required field and every optional field relevant to
the tested path; validate the fixture against the contract when tooling exists.

Do not blindly require every field in every test: that creates noisy fixtures and can
couple tests to irrelevant data. Instead, make intentional omissions explicit and
back lower-fidelity doubles with a contract or larger-scope test against the real
implementation. A hand-written partial object that merely satisfies today's access
path is not evidence of integration correctness.

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
