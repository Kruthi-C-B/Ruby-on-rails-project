import React from "react";
import "./authentication.css";

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || "";
}

function LoginForm({ adminLogin }) {
  return (
    <section className="auth-card">
      <h1>{adminLogin ? "Admin Log In" : "User Log In"}</h1>
      <form action="/login" method="post">
        <input type="hidden" name="authenticity_token" value={csrfToken()} />
        <input type="hidden" name="admin_login" value={adminLogin ? "true" : ""} />
        <label htmlFor="login-email">Email</label>
        <input id="login-email" name="email" type="email" autoComplete="email" required />
        <label htmlFor="login-password">Password</label>
        <input id="login-password" name="password" type="password" autoComplete="current-password" required />
        <button type="submit">{adminLogin ? "Log In to Store Dashboard" : "Log In"}</button>
      </form>
      <p>Don't have an account? <a href="/signup">Sign up</a></p>
    </section>
  );
}

function SignupForm({ errors = [], email = "", accountType = "user" }) {
  return (
    <section className="auth-card">
      <h1>Create an Account</h1>
      {errors.length > 0 && (
        <div role="alert" className="auth-errors">
          <ul>{errors.map((error) => <li key={error}>{error}</li>)}</ul>
        </div>
      )}
      <form action="/signup" method="post">
        <input type="hidden" name="authenticity_token" value={csrfToken()} />
        <label htmlFor="signup-email">Email</label>
        <input id="signup-email" name="user[email]" type="email" autoComplete="email" defaultValue={email} required />
        <label htmlFor="signup-password">Password</label>
        <input id="signup-password" name="user[password]" type="password" autoComplete="new-password" required />
        <label htmlFor="signup-password-confirmation">Password confirmation</label>
        <input id="signup-password-confirmation" name="user[password_confirmation]" type="password" autoComplete="new-password" required />
        <fieldset>
          <legend>What would you like to do?</legend>
          <label>
            <input type="radio" name="account_type" value="user" defaultChecked={accountType !== "owner"} />
            I want to shop for products
          </label>
          <label>
            <input type="radio" name="account_type" value="owner" defaultChecked={accountType === "owner"} />
            I want to open a store and sell products
          </label>
        </fieldset>
        <button type="submit">Sign Up</button>
      </form>
      <p>Already have an account? <a href="/login">Log in</a></p>
    </section>
  );
}

export default function AuthenticationApp({ page, adminLogin, errors, email, accountType }) {
  return (
    <main className="auth-mfe">
      {page === "signup"
        ? <SignupForm errors={errors} email={email} accountType={accountType} />
        : <LoginForm adminLogin={adminLogin} />}
    </main>
  );
}
