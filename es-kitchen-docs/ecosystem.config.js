module.exports = {
  apps: [
    {
      name: "eskitchen-docs",
      script: "venv/bin/mkdocs",
      args: "serve --dev-addr=0.0.0.0:8001",
      interpreter: "none"
    }
  ]
};
