import React, { useState, useEffect } from "react";
import { Link, useHistory } from "react-router-dom";
import { fetchGet, fetchRequest } from "../../lib/api";
import { Alert, Button, Card, Input, PageContainer, PageHeader, Spinner } from "../ui";

export default function EditStoreProfile() {
  const [formData, setFormData] = useState({ name: "", slug: "", address: "" });
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const history = useHistory();

  useEffect(() => {
    // Fetch the current user's tenant (store profile) data on load
    fetchGet("/api/v1/me")
      .then((data) => {
        if (data.tenant) {
          setFormData({
            name: data.tenant.name || "",
            slug: data.tenant.slug || "",
            address: data.tenant.address || ""
          });
        }
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      // Send the update to the new JSON API endpoint
      await fetchRequest("/api/v1/users/store_owners/tenant", "PUT", { tenant: formData });
      history.push("/product_listings"); // Redirect back to dashboard on success
    } catch (err) {
      setError(err.message || "Failed to update store profile.");
    }
  };

  if (loading) return <PageContainer size="narrow"><Spinner label="Loading profile…" /></PageContainer>;

  return (
    <PageContainer size="narrow">
      <Card>
      <PageHeader title="Edit Store Profile" />

      {error && <Alert>{error}</Alert>}

      <form onSubmit={handleSubmit} className="lf-form-stack">
          <Input
            label="Store Name"
            type="text"
            required
            value={formData.name} 
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          />

          <Input
            label="Store URL Slug"
            type="text"
            required
            value={formData.slug} 
            onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
          />

          <Input
            as="textarea"
            label="Store Address"
            required
            rows="3"
            value={formData.address} 
            onChange={(e) => setFormData({ ...formData, address: e.target.value })}
          />

        <div className="lf-form-actions">
          <Button type="submit">
            Update Profile
          </Button>
          <Button as={Link} to="/product_listings" variant="outline">
            Cancel
          </Button>
        </div>
      </form>
      </Card>
    </PageContainer>
  );
}