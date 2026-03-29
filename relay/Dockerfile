FROM denoland/deno:2.3.3

WORKDIR /app
COPY main.ts .

# Cache dependencies at build time
RUN deno cache main.ts

EXPOSE 8000
CMD ["deno", "run", "--allow-net", "--allow-env", "main.ts"]
