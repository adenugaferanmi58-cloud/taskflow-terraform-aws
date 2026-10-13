import os
import json
import boto3
from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)


def get_database_url():
    # On AWS: DB_SECRET_NAME is set, so read the credentials from Secrets Manager.
    secret_name = os.environ.get("DB_SECRET_NAME")
    if not secret_name:
        # Local development: use DATABASE_URL, or fall back to a SQLite file.
        return os.environ.get("DATABASE_URL", "sqlite:///tasks.db")

    client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    s = json.loads(client.get_secret_value(SecretId=secret_name)["SecretString"])
    return f"postgresql+psycopg2://{s['username']}:{s['password']}@{s['host']}:{s['port']}/{s['dbname']}"


app.config["SQLALCHEMY_DATABASE_URI"] = get_database_url()
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db = SQLAlchemy(app)


class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    done = db.Column(db.Boolean, default=False, nullable=False)

    def to_dict(self):
        return {"id": self.id, "title": self.title, "done": self.done}


with app.app_context():
    try:
        db.create_all()
    except Exception:
        # Another server may have created the table at the same moment.
        db.session.rollback()


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    # The load balancer calls this. It doesn't touch the database on purpose.
    return jsonify(status="ok"), 200


@app.route("/api/tasks", methods=["GET"])
def list_tasks():
    return jsonify([t.to_dict() for t in Task.query.order_by(Task.id).all()])


@app.route("/api/tasks", methods=["POST"])
def create_task():
    title = (request.get_json(silent=True) or {}).get("title", "").strip()
    if not title:
        return jsonify(error="title is required"), 400
    task = Task(title=title)
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@app.route("/api/tasks/<int:task_id>", methods=["PATCH"])
def toggle_task(task_id):
    task = db.get_or_404(Task, task_id)
    task.done = not task.done
    db.session.commit()
    return jsonify(task.to_dict())


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    task = db.get_or_404(Task, task_id)
    db.session.delete(task)
    db.session.commit()
    return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)