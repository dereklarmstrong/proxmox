# Stop Wasting Time on Proxmox Boilerplate: Meet Your New Homelab Sidekick 🚀

Hey fellow homelab nerds! 👋

If you're reading this, you probably have a Proxmox server gathering dust (or not-so-dust, let's be real) in your basement, closet, or spare bedroom. And if you're like me, you've probably found yourself doing the same thing over and over:

- Creating VM templates (again)
- Cloning VMs with the same IP config (yet again)
- Setting up backups (and then wondering if they actually work)
- Trying to remember which command sets up GPU passthrough for your gaming VM

Sound familiar? Yeah, I thought so.

## The Problem: We're All Doing It Wrong (But in a Good Way)

Here's the thing about homelabs: they're supposed to be fun. They're supposed to be our playgrounds where we learn, experiment, and build cool stuff. But somewhere along the way, we turned our "fun projects" into maintenance nightmares.

I've spent way too many evenings fighting with cloud-init configs, manually setting up VLANs, or trying to figure out why my backup didn't actually restore properly. And I'm guessing you have too, if you're still here reading this.

## Enter: The Proxmox Utility Toolkit

So I built something. Something that I wish existed when I started my homelab journey. Something that saves me hours of repetitive work and lets me focus on the stuff that actually matters: **learning and building**.

This isn't some enterprise-grade solution that costs a fortune and requires a PhD to understand. Nah, this is for **us** — the closet nerds, the homelab enthusiasts, the people who stay up way too late tweaking their Kubernetes clusters because "why not?"

## What's Actually in Here?

Let me break it down without the corporate jargon:

### 🖥️ VM & Container Magic

Want to spin up a new VM with cloud-init, a static IP, and your SSH key already configured? Done. In seconds. No more copy-pasting configs and praying to the tech gods.

```bash
# Clone a VM with everything pre-configured
bash scripts/vm/clone_vm.sh -s 9000 -d 150 -n web01 -i 192.168.1.60/24 -g 192.168.1.1
```

Boom. You're done.

### 💾 Backups That Actually Work

Backups are boring until they're not. And then they're the most important thing in the world. This toolkit helps you:

- Backup single VMs or everything at once
- Set up GFS retention (Grandfather-Father-Son, for the uninitiated)
- Generate reports so you know what's actually backed up
- Verify your backups work (because "I think it worked" isn't a strategy)

### 🎮 GPU Passthrough Without the Headaches

Trying to get your NVIDIA GPU working in a VM for AI/ML? Or maybe you just want to game on your homelab? There's documentation for both. AMD users? We got you covered with ROCm guides too.

### ☸️ Kubernetes Clusters (Because Why Not?)

Deploy a full Oracle Linux Kubernetes cluster with a single script. It's not for production (shoutout to the simplicity police), but for learning? Absolutely.

### 🔒 Security That Doesn't Suck

Zero trust architecture, CIS benchmarks, incident response — all the buzzwords, but actually explained in a way that makes sense. And yes, there's a security hardening guide because your homelab is still part of your network.

### 🤖 Automation That Actually Helps

Ansible playbooks, Terraform configs, cloud-init examples — all the automation stuff you need to stop doing things manually. Because once you automate it, you'll never go back.

## Who Is This For?

**Everyone.** Seriously.

- **Beginners**: There's a learning path that starts with "how do I create a VM?" and goes all the way to "let's implement zero trust architecture."
- **Intermediate homelabbers**: VLANs, firewalls, automated backups — all the stuff that separates the weekend warriors from the serious tinkerers.
- **Advanced nerds**: Kubernetes, GPU passthrough, infrastructure as code — build the fancy stuff once you've got the basics down.

## The Philosophy: Learn, Don't Just Deploy

Here's the thing that sets this apart: **this is a learning playground**.

I'm not telling you to deploy this in production and expect it to run your business. Nah. This is about building skills. Understanding how things work. Making mistakes in a safe environment.

As the README says it: *"Complexity = more failure points. Keep your production stuff simple, folks!"*

But hey, your homelab? Your rules. Experiment. Break things. Learn from it. That's the whole point.

## Getting Started Is Stupid Simple

```bash
git clone https://github.com/dereklarmson/proxmox.git
cd proxmox
cp config.example.sh config.sh  # Edit this with your settings
./scripts/test.sh              # Optional: make sure everything works
```

That's it. From there, you can start creating templates, cloning VMs, setting up backups — whatever you want to tackle first.

## The Real Value: Time Saved

Let me be real with you. This toolkit saved me probably 20+ hours in my first month of using it. Twenty. Hours.

- No more manually configuring cloud-init every time
- No more guessing if my backups are working
- No more Googling "how to set up VLAN in Proxmox" for the 100th time
- No more fighting with GPU passthrough configs

All that time? I spent it building actual projects. Learning new stuff. Having fun.

## So... Should You Check It Out?

**Absolutely.**

Even if you don't use every script, every guide, every automation tool — there's something here that'll save you time. Something that'll help you understand Proxmox better. Something that'll make your homelab life a little less frustrating.

And hey, if you're feeling generous, throw a star on the repo. But really, just use it. Break it. Learn from it. That's what homelabs are for.

## Let's Build Something Cool

Your homelab is your playground. Your learning lab. Your sandbox for all the tech stuff you're curious about. And this toolkit? It's just here to make that journey a little smoother.

So go ahead. Clone the repo. Tweak the configs. Break some VMs. Learn something new.

And when you're done? Come back and tell me what you built. Because that's the best part of this whole thing: **we're all in this together**.

---

*P.S. If you've got suggestions, improvements, or just want to chat about your homelab setup, the repo's open for contributions. Let's make this better together.*
