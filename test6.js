const { initializeApp } = require('firebase/app');
const { getFirestore, doc, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: 'AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ',
    appId: '1:313350964672:web:0a5ba8a1d990c433cef425',
    projectId: 'studio-6116270073-a85c2',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function test() {
    console.log("Fetching central_store...");
    const docRef = doc(db, 'app_data', 'central_store');
    const docSnap = await getDoc(docRef);
    if (docSnap.exists()) {
        const data = docSnap.data();
        const students = data.allStudents || [];
        const zayan = students.find(s => s.username === 'zayanhz02');
        console.log("Found Zayan in allStudents?", zayan ? "YES" : "NO");
        if (zayan) console.log(zayan);
        
        const teacher = (data.allTeachers || []).find(t => t.username === 'zayanhz02');
        console.log("Found Zayan in allTeachers?", teacher ? "YES" : "NO");
    } else {
        console.log("No such document!");
    }
}

test().then(() => process.exit(0));
