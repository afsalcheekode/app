const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc, collection, getDocs } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function run() {
    console.log("Checking user zayanhz02 in users collection...");
    const usersSnap = await getDocs(collection(db, 'users'));
    let found = false;
    usersSnap.forEach(doc => {
        const data = doc.data();
        if (data.username === 'zayanhz02') {
            console.log("FOUND IN USERS:", data);
            found = true;
        }
        if (data.role === 'student') {
            console.log("STUDENT:", data.username, "CLASS:", data.std, "SCHOOL:", data.schoolName);
        }
    });
    if (!found) console.log("zayanhz02 NOT FOUND in users collection");

    console.log("\nChecking central_store...");
    const centralStore = await getDoc(doc(db, 'app_data', 'central_store'));
    if (centralStore.exists()) {
        const data = centralStore.data();
        const students = data.allStudents || [];
        console.log(`Found ${students.length} students in central store.`);
        const zayan = students.find(s => s.username === 'zayanhz02');
        if (zayan) {
            console.log("FOUND IN CENTRAL STORE:", zayan);
        } else {
            console.log("zayanhz02 NOT FOUND in central store");
        }
    }
}

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
