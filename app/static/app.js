const list = document.getElementById("list");
const empty = document.getElementById("empty");
const count = document.getElementById("count");
const form = document.getElementById("form");
const input = document.getElementById("title");

async function load() {
  const response = await fetch("/api/tasks");
  const tasks = await response.json();

  list.innerHTML = "";

  tasks.forEach(task => {
    const li = document.createElement("li");
    if (task.done) li.classList.add("done");

    // Round check button: click to mark done or not done
    const check = document.createElement("button");
    check.className = "check";
    check.type = "button";
    check.textContent = task.done ? "✓" : "";
    check.onclick = async () => {
      await fetch(`/api/tasks/${task.id}`, { method: "PATCH" });
      load();
    };

    // The task text (textContent keeps any typed HTML from running)
    const label = document.createElement("span");
    label.textContent = task.title;

    // Delete button
    const del = document.createElement("button");
    del.className = "delete";
    del.type = "button";
    del.textContent = "Delete";
    del.onclick = async () => {
      await fetch(`/api/tasks/${task.id}`, { method: "DELETE" });
      load();
    };

    li.append(check, label, del);
    list.appendChild(li);
  });

  const open = tasks.filter(task => !task.done).length;
  count.textContent = `${open} open`;
  empty.hidden = tasks.length > 0;
}

form.onsubmit = async event => {
  event.preventDefault();
  const title = input.value.trim();
  if (!title) return;

  await fetch("/api/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title })
  });

  input.value = "";
  load();
};

load();