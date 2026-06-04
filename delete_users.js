const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');
const { execSync } = require('child_process');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function run() {
    const snap = await getDocs(collection(db, 'users'));
    const uidsToDelete = [];
    snap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'student' || data.role === 'teacher') {
            uidsToDelete.push(doc.id);
        }
    });

    console.log(`Found ${uidsToDelete.length} students/teachers to delete from Auth.`);
    
    // Batch delete them using firebase CLI
    const batchSize = 100;
    for (let i = 0; i < uidsToDelete.length; i += batchSize) {
        const batch = uidsToDelete.slice(i, i + batchSize);
        const uidsStr = batch.join(',');
        console.log(`Deleting batch ${i/batchSize + 1}...`);
        try {
            execSync(`npx firebase auth:delete ${uidsStr} --force`, { stdio: 'inherit' });
        } catch (e) {
            console.error("Error deleting batch:", e);
        }
    }
    console.log("Done.");
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
