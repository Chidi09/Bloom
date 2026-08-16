import { describe, expect, it } from "bun:test";
import { z } from "zod";

// Schemas mirroring login and registration validation
const loginSchema = z.object({
  email: z
    .string()
    .min(1, "Email is required")
    .email("Please enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

const registerSchema = z.object({
  name: z.string().min(1, "Name is required").max(100, "Name is too long"),
  email: z
    .string()
    .min(1, "Email is required")
    .email("Please enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

describe("Auth validation and contracts", () => {
  it("validates login payload correctly", () => {
    const valid = loginSchema.safeParse({
      email: "user@example.com",
      password: "securepassword123",
    });
    expect(valid.success).toBe(true);

    const invalidEmail = loginSchema.safeParse({
      email: "not-an-email",
      password: "password123",
    });
    expect(invalidEmail.success).toBe(false);
  });

  it("validates registration payload correctly", () => {
    const valid = registerSchema.safeParse({
      name: "Ada Lovelace",
      email: "ada@example.com",
      password: "password123",
    });
    expect(valid.success).toBe(true);

    const shortPassword = registerSchema.safeParse({
      name: "Ada Lovelace",
      email: "ada@example.com",
      password: "short",
    });
    expect(shortPassword.success).toBe(false);
  });

  it("constructs matching backend registration and login payloads", () => {
    const email = "Ada.Lovelace@example.com";
    const password = "password123";

    const registrationPayload = {
      username: email.trim(),
      email: email.trim(),
      password,
    };

    const loginPayload = {
      username: email.trim(),
      password,
    };

    expect(registrationPayload.username).toBe(loginPayload.username);
    expect(registrationPayload.email).toBe("Ada.Lovelace@example.com");
  });
});
