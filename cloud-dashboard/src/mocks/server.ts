import { setupServer } from "msw/node";
import { handlers } from "@/mocks/handlers";

// Used by tests/integration — call server.listen()/resetHandlers()/close() in test setup.
export const server = setupServer(...handlers);
