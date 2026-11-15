// Demo data. `npm run seed` wipes the database and reloads it.
const bcrypt = require('bcryptjs');
const { db, tx } = require('./db');

const PASSWORD = 'password123';

const RESTAURANTS = [
  {
    owner: { name: 'Burger House Owner', email: 'burger@demo.com' },
    name_en: 'Burger House', name_ar: 'بيت البرجر',
    desc_en: 'Smash burgers, fries and shakes', desc_ar: 'برجر سماش وبطاطس وميلك شيك',
    category_en: 'Burgers', category_ar: 'برجر', delivery_time_min: 25, min_order: 50, delivery_fee: 15, rating: 4.6,
    menu: [
      ['Burgers', 'برجر', 'Classic Smash Burger', 'برجر سماش كلاسيك', 'Double beef patty, cheese, house sauce', 'قطعتين لحم، جبنة، صوص خاص', 145],
      ['Burgers', 'برجر', 'Chicken Crispy Burger', 'برجر فراخ كرسبي', 'Fried chicken breast, lettuce, mayo', 'صدر فراخ مقلي، خس، مايونيز', 120],
      ['Burgers', 'برجر', 'Mushroom Swiss', 'مشروم سويس', 'Beef, sautéed mushrooms, swiss cheese', 'لحم، مشروم سوتيه، جبنة سويسري', 165],
      ['Sides', 'إضافات', 'French Fries', 'بطاطس مقلية', 'Crispy salted fries', 'بطاطس مقرمشة', 45],
      ['Sides', 'إضافات', 'Onion Rings', 'حلقات بصل', '8 pieces', '٨ قطع', 50],
      ['Drinks', 'مشروبات', 'Chocolate Shake', 'ميلك شيك شوكولاتة', '400 ml', '٤٠٠ مل', 70],
    ],
  },
  {
    owner: { name: 'Pizza Roma Owner', email: 'pizza@demo.com' },
    name_en: 'Pizza Roma', name_ar: 'بيتزا روما',
    desc_en: 'Wood-fired Italian pizza', desc_ar: 'بيتزا إيطالي في فرن الحطب',
    category_en: 'Pizza', category_ar: 'بيتزا', delivery_time_min: 35, min_order: 80, delivery_fee: 20, rating: 4.4,
    menu: [
      ['Pizza', 'بيتزا', 'Margherita', 'مارجريتا', 'Tomato, mozzarella, basil', 'صلصة طماطم، موتزاريلا، ريحان', 130],
      ['Pizza', 'بيتزا', 'Pepperoni', 'بيبروني', 'Beef pepperoni, mozzarella', 'بيبروني لحم، موتزاريلا', 165],
      ['Pizza', 'بيتزا', 'Four Cheese', 'أربع أجبان', 'Mozzarella, cheddar, parmesan, blue cheese', 'موتزاريلا، شيدر، بارميزان، ريكفورد', 175],
      ['Pasta', 'مكرونة', 'Penne Arrabbiata', 'بيني أرابياتا', 'Spicy tomato sauce', 'صلصة طماطم حارة', 110],
      ['Desserts', 'حلويات', 'Tiramisu', 'تيراميسو', 'Classic Italian dessert', 'حلوى إيطالية كلاسيك', 85],
    ],
  },
  {
    owner: { name: 'Koshary El Tahrir Owner', email: 'koshary@demo.com' },
    name_en: 'Koshary Corner', name_ar: 'ركن الكشري',
    desc_en: 'Traditional Egyptian street food', desc_ar: 'أكل شعبي مصري',
    category_en: 'Egyptian', category_ar: 'مصري', delivery_time_min: 20, min_order: 30, delivery_fee: 10, rating: 4.8,
    menu: [
      ['Koshary', 'كشري', 'Koshary Medium', 'كشري وسط', 'Rice, lentils, pasta, tomato sauce, fried onions', 'رز، عدس، مكرونة، صلصة، بصل مقرمش', 45],
      ['Koshary', 'كشري', 'Koshary Large', 'كشري كبير', 'Large portion', 'حجم كبير', 60],
      ['Sandwiches', 'سندوتشات', 'Falafel Sandwich', 'سندوتش طعمية', 'With tahini and salad', 'بالطحينة والسلطة', 15],
      ['Sandwiches', 'سندوتشات', 'Foul Sandwich', 'سندوتش فول', 'Fava beans with oil and cumin', 'فول بالزيت والكمون', 12],
      ['Desserts', 'حلويات', 'Rice Pudding', 'أرز باللبن', 'Topped with nuts', 'بالمكسرات', 30],
    ],
  },
  {
    owner: { name: 'Sushi Zen Owner', email: 'sushi@demo.com' },
    name_en: 'Sushi Zen', name_ar: 'سوشي زن',
    desc_en: 'Fresh sushi and Asian bowls', desc_ar: 'سوشي طازج وأطباق آسيوية',
    category_en: 'Asian', category_ar: 'آسيوي', delivery_time_min: 40, min_order: 150, delivery_fee: 25, rating: 4.3,
    menu: [
      ['Sushi', 'سوشي', 'California Roll', 'كاليفورنيا رول', '8 pieces, crab, avocado', '٨ قطع، كابوريا، أفوكادو', 180],
      ['Sushi', 'سوشي', 'Salmon Nigiri', 'نيجيري سلمون', '4 pieces', '٤ قطع', 210],
      ['Bowls', 'أطباق', 'Chicken Teriyaki Bowl', 'طبق دجاج ترياكي', 'Rice, chicken, teriyaki sauce', 'رز، دجاج، صوص ترياكي', 160],
    ],
  },
];

function seed() {
  const hash = bcrypt.hashSync(PASSWORD, 10);
  tx(() => {
    const addUser = db.prepare('INSERT INTO users (name, email, phone, password_hash, role, is_online) VALUES (?, ?, ?, ?, ?, ?)');
    addUser.run('Admin', 'admin@demo.com', '01000000000', hash, 'admin', 0);
    addUser.run('Ahmed Customer', 'customer@demo.com', '01011111111', hash, 'customer', 0);
    addUser.run('Mohamed Driver', 'driver@demo.com', '01022222222', hash, 'driver', 1);

    const addRest = db.prepare(`INSERT INTO restaurants (owner_id, name_en, name_ar, desc_en, desc_ar, category_en, category_ar,
      delivery_time_min, min_order, delivery_fee, rating) VALUES (?,?,?,?,?,?,?,?,?,?,?)`);
    const addItem = db.prepare(`INSERT INTO menu_items (restaurant_id, section_en, section_ar, name_en, name_ar, desc_en, desc_ar, price)
      VALUES (?,?,?,?,?,?,?,?)`);
    for (const r of RESTAURANTS) {
      const owner = addUser.run(r.owner.name, r.owner.email, null, hash, 'restaurant', 0).lastInsertRowid;
      const rid = addRest.run(owner, r.name_en, r.name_ar, r.desc_en, r.desc_ar, r.category_en, r.category_ar,
        r.delivery_time_min, r.min_order, r.delivery_fee, r.rating).lastInsertRowid;
      for (const m of r.menu) addItem.run(rid, ...m);
    }
  });
}

function reset() {
  db.exec(`DELETE FROM order_events; DELETE FROM order_items; DELETE FROM orders;
    DELETE FROM menu_items; DELETE FROM restaurants; DELETE FROM users;
    DELETE FROM sqlite_sequence;`);
}

if (require.main === module) {
  reset();
  seed();
  console.log(`Seeded. All demo accounts use password "${PASSWORD}":`);
  console.log('  admin@demo.com, customer@demo.com, driver@demo.com,');
  console.log('  burger@demo.com, pizza@demo.com, koshary@demo.com, sushi@demo.com');
}

module.exports = { seed, reset, PASSWORD };
