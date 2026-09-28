import express from "express";
import { authRouter } from "./routes/auth";
import { productsRouter } from "./routes/products";
import { cartRouter } from "./routes/cart";
import { errorHandler } from "./errors";

const app = express();
app.use(express.json());
app.use("/auth", authRouter);
app.use("/products", productsRouter);
app.use("/cart", cartRouter);
app.use(errorHandler);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`bff listening on ${port}`));
