import React from "react";
import { Link } from "react-router-dom";
import { Button, Card } from "../ui";

export default function ProductCard({ product, image, price }) {
  const imageContent = typeof image === "string"
    ? <img src={image} alt="" loading="lazy" />
    : image;

  return (
    <Card
      className="lf-product-card"
      title={product.name}
      description={product.description}
      image={imageContent}
      footer={
        <Button as={Link} to={`/products/${product.id}`} variant="outline">
          Compare Prices
        </Button>
      }
    >
      <p className="lf-product-card__category">
        <strong>Category:</strong> {typeof product.category === "object" ? product.category?.name : product.category}
      </p>
      {price != null && (
        <p className="lf-product-card__price">${Number(price).toFixed(2)}</p>
      )}
    </Card>
  );
}
