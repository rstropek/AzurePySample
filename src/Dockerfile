FROM python:3.12-slim

WORKDIR /app

COPY Pipfile Pipfile.lock ./

RUN pip install pipenv && \
    pipenv install --deploy --system && \
    pip uninstall -y pipenv

COPY .env .env
COPY src/ ./src/

EXPOSE 8080

CMD ["fastapi", "run", "src/main.py", "--host", "0.0.0.0", "--port", "8080"] 
