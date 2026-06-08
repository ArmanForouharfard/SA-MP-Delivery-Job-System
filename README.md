<img width="1917" height="1001" alt="customers table" src="https://github.com/user-attachments/assets/b6cd422d-2a50-4b5b-a35b-87ef13e59eb4" /># 🚚 SA-MP Delivery Job System

A complete, professional delivery job system for SA-MP / open.mp multiplayer mod for GTA San Andreas.

## ✨ Features

### Core Systems
- ✅ MySQL database integration (products, customers, delivery history)
- ✅ Actor NPC at job start location
- ✅ Product & Customer selection dialogs
- ✅ Dynamic price calculation (distance × sensitivity)
- ✅ Pickup and destination checkpoints
- ✅ Job vehicle spawning (`/deliveryvehicle`)
- ✅ 2-minute timer on vehicle exit
- ✅ Payment system on delivery

### NO-REPEAT System (Hybrid)
- 🔄 Blocks same product to same customer for 1 hour
- ⏰ Automatic unlock after 1 hour
- 💾 Database tracking with `delivery_history` table
- 🎮 Players cannot exploit by reconnecting

### Optional Features
- 👥 Customer actors at destination locations
- 📦 Object in hand system (visible product while walking)
- 💬 Thank you message on delivery completion

## 📋 Commands

| Command | Description |
|---------|-------------|
| `/gotodelivery` | Teleport to job location |
| `/deliverprod` | Start a delivery job |
| `/deliveryvehicle` | Spawn delivery truck |
| `/deliveryhelp` | Show help menu |

## 🗄️ Database Structure

```sql
pawncourse2
├── products (id, name, base_price, sensitivity)
├── customers (id, name, pos_x, pos_y, pos_z)
└── delivery_history (id, player_name, product_id, customer_id, delivered_at)

## 📸 ScreenShots
## 1) DataBase
<img width="1917" height="984" alt="pawncourse 2 database with customers   delivery history   products tables" src="https://github.com/user-attachments/assets/f682b221-25be-4d7d-9c11-f73b730ab3a3" />

<img width="1917" height="1001" alt="customers table" src="https://github.com/user-attachments/assets/7ae2bf62-8b11-45e1-9bdb-215e2d8e9582" />

<img width="1918" height="1001" alt="delivery history table" src="https://github.com/user-attachments/assets/6fa13822-c8c5-4c24-bfae-eea6e3c3bf41" />

<img width="1920" height="1004" alt="products table" src="https://github.com/user-attachments/assets/5f55e299-a888-4083-a22a-fc7092f2e1ee" />


