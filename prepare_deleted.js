const fs = require('fs');

const rawData = fs.readFileSync('temp_users.json', 'utf8');
const data = JSON.parse(rawData);
const uidsToDelete = fs.readFileSync('uids_to_delete.txt', 'utf8').split(' ');

const updatedUsers = [];

for (const user of data.users) {
  if (uidsToDelete.includes(user.localId)) {
    // Append _deleted so the original email is freed!
    updatedUsers.push({
      localId: user.localId,
      email: user.email.replace('@', '_deleted@'),
      passwordHash: user.passwordHash,
      salt: user.salt
    });
  }
}

fs.writeFileSync('deleted_users.json', JSON.stringify({users: updatedUsers}));
console.log(`Prepared ${updatedUsers.length} users to be archived to free up their names.`);
