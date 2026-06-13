FROM python:3.12-slim

WORKDIR /srv

# Install deps first for layer caching.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY scripts ./scripts

# SQLite lives on a mounted volume so data survives container recreation.
ENV DB_PATH=/data/plug_gateway.db
EXPOSE 8099

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8099"]
