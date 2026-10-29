
import React, { useState } from "react";
import { useHistory } from "react-router-dom";
import { fetchRequest } from "../../lib/api";
import { Alert, Button, Card, Input, PageContainer, PageHeader } from "../ui";

export default function CreateStoreProfile() {
  const [formData, setFormData] = useState({
    name: "",
    slug: "",
    address: "",
  });

  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const history = useHistory();

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      await fetchRequest("/api/v1/users/store_owners/tenant", "POST", {
        tenant: formData,
      });

      history.push("/product_listings");
    } catch (err) {
      setError(err.message || "Failed to create store profile.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <PageContainer size="narrow">
      <Card>
        <PageHeader title="Create Store Profile" />

        {error && <Alert>{error}</Alert>}

        <form onSubmit={handleSubmit} className="lf-form-stack">
          <Input
            id="name"
            label="Store Name"
            name="name"
            type="text"
            value={formData.name}
            onChange={handleChange}
            placeholder="Enter store name"
            required
          />

          <Input
            id="slug"
            label="URL Slug (e.g. techhub-downtown)"
            name="slug"
            type="text"
            value={formData.slug}
            onChange={handleChange}
            placeholder="techhub-downtown"
            required
            pattern="[a-zA-Z0-9-]+"
            title="Use letters, numbers, and hyphens only."
          />

          <Input
            as="textarea"
            id="address"
            label="Store Address"
            name="address"
            rows="3"
            value={formData.address}
            onChange={handleChange}
            placeholder="Enter store address"
          />

          <Button type="submit" loading={loading}>
            {loading ? "Saving..." : "Save Store Profile"}
          </Button>
        </form>
      </Card>
    </PageContainer>
  );
}