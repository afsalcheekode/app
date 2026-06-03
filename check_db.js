const { initializeApp } = require("firebase/app");
const { getFirestore, collection, getDocs, doc, getDoc } = require("firebase/firestore");

const firebaseConfig = {
  apiKey: "AIzaSyDtzmMvUktdEvlK-_6_vB_k3O6paWlznWQ",
  appId: "1:313350964672:web:0a5ba8a1d990c433cef425",
  projectId: "studio-6116270073-a85c2",
  authDomain: "studio-6116270073-a85c2.firebaseapp.com",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function checkData() {
  try {
    const usersSnapshot = await getDocs(collection(db, "users"));
    console.log(`Found ${usersSnapshot.size} documents in 'users' collection.`);
    let studentCount = 0;
    let teacherCount = 0;
    
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.role === 'student') studentCount++;
      if (data.role === 'teacher') teacherCount++;
    });
    
    console.log(`- Students: ${studentCount}`);
    console.log(`- Teachers: ${teacherCount}`);
    
    const centralStoreDoc = await getDoc(doc(db, "app_data", "central_store"));
    if (centralStoreDoc.exists()) {
      const data = centralStoreDoc.data();
      console.log("\ncentral_store exists.");
      console.log(`- allTeachers length: ${data.allTeachers ? data.allTeachers.length : 0}`);
      console.log(`- allStudents length: ${data.allStudents ? data.allStudents.length : 0}`);
      console.log(`- allMessages length: ${data.allMessages ? data.allMessages.length : 0}`);
    } else {
      console.log("\ncentral_store DOES NOT EXIST!");
    }
    
    process.exit(0);
  } catch (error) {
    console.error("Error fetching data:", error);
    process.exit(1);
  }
}

checkData();
