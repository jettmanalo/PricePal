import SwiftUI
import VisionKit
import FirebaseFirestore
import FirebaseAuth

struct ContentView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var shopName = ""
    
    @State private var emailForReset = ""
    @State private var isLoggingIn = true
    @State private var isRegestering = false
    @State private var isRegistrationSuccessful = false
    @State private var errorMessage: String?
    @State private var showResetPassword = false
    
    @State private var itemName = ""
    @State private var itemBarcode = ""
    @State private var itemPrice = ""
    @State private var items: [String: [String: Any]] = [:]
    
    @State private var selectedShop: String = "Select shop"
    @State private var scannedBarcode: String = "Barcode"
    @State private var fetchedItemName: String = "Unknown item"
    @State private var fetchedItemPrice: String = "0"
    
    @State private var shops: [String] = []
    @State private var view = "inventoryView"
    
    func fetchShopNames() {
        let db = Firestore.firestore()
        let shopsRef = db.collection("shops")
        
        shopsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching shop names: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("No shops found.")
                return
            }
            
            var names: [String] = []
            
            for document in snapshot.documents {
                let shopName = document.documentID
                names.append(shopName)
            }
            
            DispatchQueue.main.async {
                self.shops = names
            }
        }
    }
    
    func fetchShopName() {
        guard let user = Auth.auth().currentUser else {
            print("User is not authenticated.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let shopName = document.get("shopName") as? String else {
                print("Shop name not found for user.")
                return
            }
            
            self.shopName = shopName
            print("Shop name fetched: \(shopName)")
        }
    }
    
    func fetchItemDetails(forBarcode barcode: String, selectedShop: String) {
        let db = Firestore.firestore()
        let shopRef = db.collection("shops").document(selectedShop)
        
        shopRef.getDocument { document, error in
            if let error = error {
                print("Error fetching shop data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("No data found for the shop \(selectedShop).")
                return
            }
            
            self.fetchedItemName = "Unknown item"
            self.fetchedItemPrice = "0"
            
            if let itemsData = document.data(), let itemData = itemsData[barcode] as? [String: Any] {
                if let itemName = itemData["itemName"] as? String,
                   let itemPrice = itemData["itemPrice"] as? String {
                    self.fetchedItemName = itemName
                    self.fetchedItemPrice = itemPrice
                } else {
                    print("Item not found for the provided barcode.")
                }
            } else {
                print("No item found with barcode \(barcode) in shop \(selectedShop).")
            }
        }
    }
    
    private var scannerView: some View {
        VStack(spacing: 15) {
            BarcodeScannerView(scannedBarcode: $scannedBarcode)
                .edgesIgnoringSafeArea(.all)

            VStack {
                VStack {
                    Picker("Select Shop", selection: $selectedShop) {
                        Text("Select Shop").tag("Select shop")
                        ForEach(shops, id: \.self) { shop in
                            Text(shop).tag(shop)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.title2)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(fetchedItemName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(scannedBarcode)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("P \(fetchedItemPrice)")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Price")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Button(action: {
                    scannedBarcode = "Barcode"
                    fetchedItemName = "Unknown item"
                    fetchedItemPrice = "0"
                }) {
                    Text("Scan Again")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            fetchShopNames()
        }
        .onChange(of: scannedBarcode) { oldBarcode, newBarcode in
            if newBarcode != "Barcode" {
                fetchItemDetails(forBarcode: newBarcode, selectedShop: selectedShop)
            }
        }
    }
    
    func sendPasswordReset() {
        Auth.auth().sendPasswordReset(withEmail: emailForReset) { error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "Password reset email sent!"
            }
        }
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isLoggingIn = false
                errorMessage = nil
            }
        }
    }
    
    private var loginView: some View {
        VStack {
            Spacer()
            Text("Log in")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Please enter your details.")
                .font(.subheadline)
                .foregroundColor(Color.gray)
            
            Text("Email Address")
                .padding(.top)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Email Address", text: $email)
                .padding()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)

            Text("Password")
                .padding(.top, 5)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            SecureField("Password", text: $password)
                .padding()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                
            Button(action: {
                showResetPassword = true
            }) {
                Text("Forgot Password?")
                    .foregroundColor(Color.blue)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
                
            .sheet(isPresented: $showResetPassword) {
                VStack {
                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Enter your email to reset your password:")
                        .font(.subheadline)
                        .foregroundColor(Color.gray)
                    Text("Email Address")
                        .padding(.top)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Email", text: $emailForReset)
                        .padding()
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    Button(action: {
                        sendPasswordReset()
                        showResetPassword = false
                    }) {
                        Text("Send Reset Email")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                emailForReset.isEmpty ? Color.gray : Color.blue
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .disabled(emailForReset.isEmpty)
                    .padding(.top, 10)
                    
                    Button(action: {
                        showResetPassword = false
                    }) {
                        Text("Cancel")
                            .padding()
                    }
                }
                .padding(30)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(Color.red)
            }
            
            Button(action: {
                login()
            }) {
                Text("Log In")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        email.isEmpty || password.isEmpty ? Color.gray : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .disabled(email.isEmpty || password.isEmpty)
            .padding(.top, 10)
            
            Spacer()
            Spacer()
            
            HStack {
                Text("Don't have an account yet?")
                    .foregroundColor(Color.gray)
                
                Button(action: {
                    isLoggingIn = false
                    isRegestering = true
                }) {
                    Text("Register")
                        .foregroundColor(Color.blue)
                }
            }
        }
        .padding(30)
    }
    
    func register() {
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = "Failed to register: \(error.localizedDescription)"
                return
            }
            
            let db = Firestore.firestore()
            let uid = authResult?.user.uid ?? ""
            db.collection("users").document(uid).setData([
                "email": email,
                "shopName": shopName
            ]) { err in
                if let err = err {
                    errorMessage = "Failed to save user data: \(err.localizedDescription)"
                } else {
                    email = ""
                    password = ""
                    isRegestering = false
                    isLoggingIn = true
                }
            }
        }
    }
    
    private var registerView: some View {
        VStack {
            Spacer()
            Text("Register")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Create an account")
                .font(.subheadline)
                .foregroundColor(Color.gray)
            
            Text("Email Address")
                .padding(.top)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Email Address", text: $email)
                .padding()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            
            Text("Password")
                .padding(.top, 5)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            SecureField("Password", text: $password)
                .padding()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
            
            Text("Shop Name")
                .padding(.top, 5)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Shop name", text: $shopName)
                .padding()
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(Color.red)
            }
            
            Button(action: {
                register()
            }) {
                Text("Register")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        email.isEmpty || password.isEmpty || shopName.isEmpty ? Color.gray : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            .disabled(email.isEmpty && password.isEmpty && shopName.isEmpty)

            
            Spacer()
            Spacer()
            
            HStack {
                Text("Already have an account?")
                    .foregroundColor(Color.gray)
                
                Button(action: {
                    isRegestering = false
                    isLoggingIn = true
                }) {
                    Text("Log In")
                        .foregroundColor(Color.blue)
                }
            }
        }
        .padding(30)
    }
    
    func addItem() {
        guard !itemBarcode.isEmpty, !itemName.isEmpty, !itemPrice.isEmpty else {
            print("All fields are required.")
            return
        }
        
        guard let user = Auth.auth().currentUser else {
            print("User is not authenticated.")
            return
        }
        
        let db = Firestore.firestore()
        
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let shopName = document.get("shopName") as? String else {
                print("Shop name not found for user.")
                return
            }
            
            let shopRef = db.collection("shops").document(shopName)
            let itemData: [String: Any] = [
                "itemName": itemName,
                "itemPrice": itemPrice
            ]
            
            shopRef.setData([itemBarcode: itemData], merge: true) { error in
                if let error = error {
                    print("Error adding item: \(error.localizedDescription)")
                } else {
                    print("Item added successfully.")
                    itemName = ""
                    itemBarcode = ""
                    itemPrice = ""
                    
                    fetchItems()
                }
            }
        }
    }
    
    private func fetchItems() {
        guard let user = Auth.auth().currentUser else {
            print("User is not authenticated.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let shopName = document.get("shopName") as? String else {
                print("Shop name not found for user.")
                return
            }
            
            let shopRef = db.collection("shops").document(shopName)
            shopRef.getDocument { document, error in
                if let error = error {
                    print("Error fetching shop data: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("No items found for shop.")
                    return
                }
                
                if let itemsData = document.data() {
                    self.items = itemsData as? [String: [String: Any]] ?? [:]
                }
            }
        }
    }
    
    func removeItem(barcode: String) {
        guard let user = Auth.auth().currentUser else {
            print("User is not authenticated.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let shopName = document.get("shopName") as? String else {
                print("Shop name not found for user.")
                return
            }
            
            let shopRef = db.collection("shops").document(shopName)
            
            shopRef.updateData([barcode: FieldValue.delete()]) { error in
                if let error = error {
                    print("Error removing item: \(error.localizedDescription)")
                } else {
                    print("Item removed successfully.")
                }
            }
        }
    }
    
    private var inventoryView: some View {
        VStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(shopName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                HStack {
                    TextField("Barcode", text: $itemBarcode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Price", text: $itemPrice)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack(spacing: 16) {
                    TextField("Item name", text: $itemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        addItem()
                    }) {
                        Text("+ Add")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            ScrollView {
                ForEach(items.keys.sorted(), id: \.self) { barcode in
                    if let item = items[barcode] {
                        let itemName = item["itemName"] as? String ?? "Unknown"
                        let itemPrice = item["itemPrice"] as? String ?? "Unknown"
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(itemName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(barcode)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("P \(itemPrice)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Button(action: {
                                    removeItem(barcode: barcode)
                                    items.removeValue(forKey: barcode)
                                }) {
                                    Text("Remove")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.bottom, 5)
                    }
                }
                .padding(.bottom)
            }
            .padding(.top, 10)
        }
        .onAppear {
            fetchItems()
            fetchShopName()
        }
        .padding(.top, 20)
        .padding(.horizontal, 30)
    }
    
    var body: some View {
        VStack {
            VStack {
                Text("PricePal")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(Color.white)
                    .padding(.top, 10)
                Picker("", selection: $view) {
                    Text("Inventory").tag("inventoryView")
                    Text("Scanner").tag("scannerView")
                }
                .pickerStyle(.segmented)
                .padding(2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 2)
                )
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            
            Spacer()
            
            switch view {
            case "inventoryView":
                if isLoggingIn {
                    loginView
                } else if isRegestering {
                    registerView
                } else {
                    inventoryView
                }
            case "scannerView":
                scannerView
            default:
                loginView
            }
        }
    }
}

#Preview {
    ContentView()
}
