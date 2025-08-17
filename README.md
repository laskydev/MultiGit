# 🚀 MultiGit  

**Manage multiple Git identities with style and zero hassle.**  
No more copy-pasting configs or messing with `git config` every time you switch between your work, personal, or freelance accounts.  
With **MultiGit**, switching users is as easy as running a single command.  

---

## ✨ Features  

- 🔍 **Check current user** – instantly see which identity is active.  
- 🔄 **Switch users on the fly** – swap between accounts in seconds.  
- ➕ **Add new identities** – organize personal, work, and side projects.  
- 📋 **List saved users** – keep track of all your Git personas.  
- 🎨 **Interactive menu** – or just run it with options for power users.  
- 🛡️ **Safe & simple** – users are stored in a JSON file, no magic, no headaches.  

---

## 📦 Installation  

```bash
# Clone the repo
git clone https://github.com/yourusername/multigit.git

# Make it executable
chmod +x multigit.sh

# (Optional) Move it to a directory in your PATH
sudo mv multigit.sh /usr/local/bin/multigit
```

---

## 🚀 Usage  

Run it without arguments for the **interactive menu**:  

```bash
multigit
```

Or use commands directly:  

```bash
multigit current   # Show current Git user
multigit switch    # Switch to another saved user
multigit add       # Add a new user
multigit list      # List all saved users
multigit help      # Show help
```

---

## 🖥️ Demo (sneak peek)  

```
═══════════════════════════════════════
        🔧 Git User Manager
═══════════════════════════════════════

📋 CURRENT USER

👤 Name: John Doe  
📧 Email: john@work.com  

📁 Current Repo: multigit  
   URL: git@github.com:john/multigit.git
```

---

## 💡 Example workflow  

```bash
# Add a work account
multigit add
# ID: work
# Name: John Doe
# Email: john@company.com

# Add a personal account
multigit add
# ID: personal
# Name: John Dev
# Email: john.dev@gmail.com

# Switch between them anytime
multigit switch
```

---

## 🐙 Why MultiGit?  

Because developers are multitaskers. You might be:  
- contributing to open source with your **personal account**,  
- pushing code at your **day job**,  
- freelancing with a **client repo**,  
- or all three in the same day.  

**MultiGit makes identity management painless.** One command, zero headaches.  

---

## 📖 Roadmap  

- [ ] Auto-detect SSH keys per user  
- [ ] Export/import users across machines  
- [ ] Fuzzy search for faster user switching  
- [ ] Zsh/Bash completions  

---

## ⚡ Quick tagline  

> **MultiGit – one CLI, all your Git identities.**

