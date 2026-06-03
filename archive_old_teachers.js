const fs = require('fs');

const rawData = fs.readFileSync('current_auth.json', 'utf8');
const data = JSON.parse(rawData);

const targets = ['hsh@harakat.com', 'mun@harakat.com', 'ahs@harakat.com', 'mah@harakat.com'];
const updatedUsers = [];

for (const user of data.users) {
  if (targets.includes(user.email)) {
    updatedUsers.push({
      localId: user.localId,
      email: user.email.replace('@', '_old@'),
      passwordHash: user.passwordHash,
      salt: user.salt
    });
  }
}

fs.writeFileSync('archive_old_teachers.json', JSON.stringify({users: updatedUsers}));
console.log(`Prepared ${updatedUsers.length} old accounts to be archived to free up their emails.`);
