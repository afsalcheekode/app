const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function run() {
    const snap = await getDocs(collection(db, 'users'));
    snap.forEach(doc => {
        const data = doc.data();
        if (data.role === 'director' || data.role === 'admin' || data.role === 'academic_director' || data.username?.includes('hsh')) {
            console.log("DIRECTOR/ADMIN:", data.username, "SCHOOL:", data.schoolName);
        }
    });
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
