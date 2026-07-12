// app.js - Creania Admin Portal Operations & Charts Binding

document.addEventListener("DOMContentLoaded", () => {
    initTabs();
    initCharts();
    renderApprovals();
    renderPayouts();
    initSettings();
});

// ─── TAB NAVIGATION ───
function initTabs() {
    const navItems = document.querySelectorAll(".nav-item");
    const tabContents = document.querySelectorAll(".tab-content");

    navItems.forEach(item => {
        item.addEventListener("click", (e) => {
            e.preventDefault();
            const targetTab = item.getAttribute("data-tab");

            navItems.forEach(i => i.classList.remove("active"));
            item.classList.add("active");

            tabContents.forEach(tab => {
                tab.classList.remove("active");
                if (tab.id === `tab-${targetTab}`) {
                    tab.classList.add("active");
                }
            });
        });
    });
}

// ─── CHART GRAPHICS (CHART.JS) ───
let revenueChartInstance, subscriptionChartInstance;

function initCharts() {
    const revCtx = document.getElementById('revenueChart').getContext('2d');
    const subCtx = document.getElementById('subscriptionChart').getContext('2d');

    // Revenue Stream Line + Bar Chart
    revenueChartInstance = new Chart(revCtx, {
        type: 'line',
        data: {
            labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
            datasets: [{
                label: 'INR Revenues (₹)',
                data: [120000, 150000, 220000, 310000, 290000, 410000, 485900],
                borderColor: '#6366F1',
                backgroundColor: 'rgba(99, 102, 241, 0.05)',
                borderWidth: 3,
                tension: 0.35,
                fill: true
            }, {
                label: 'Coins Recharges (Tokens)',
                type: 'bar',
                data: [250000, 400000, 600000, 850000, 720000, 1100000, 1200000],
                backgroundColor: 'rgba(255, 184, 0, 0.25)',
                borderColor: '#FFB800',
                borderWidth: 1,
                borderRadius: 6
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { labels: { color: '#64748B', font: { family: 'Plus Jakarta Sans', weight: '600' } } }
            },
            scales: {
                x: { grid: { color: 'rgba(255,255,255,0.02)' }, ticks: { color: '#64748B' } },
                y: { grid: { color: 'rgba(255,255,255,0.02)' }, ticks: { color: '#64748B' } }
            }
        }
    });

    // Subscriptions Doughnut Split
    subscriptionChartInstance = new Chart(subCtx, {
        type: 'doughnut',
        data: {
            labels: ['VIP Level 1-3', 'VIP Level 4-7', 'Novel 1-3', 'Novel 4-7'],
            datasets: [{
                data: [35, 15, 30, 20],
                backgroundColor: ['#3B82F6', '#8B5CF6', '#10B981', '#064E3B'],
                borderWidth: 0
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { 
                    position: 'bottom',
                    labels: { color: '#64748B', padding: 15, font: { family: 'Plus Jakarta Sans', weight: '600' } } 
                }
            }
        }
    });
}

// ─── LIST DATA & ACTIONS ───
let mockApprovals = [
    {
        id: "app_1",
        title: "BTech ECE Microcontrollers Lab Manual",
        category: "Engineering",
        sellerName: "Aditya Roy",
        sellingPrice: 120.00,
        thumbnail: "https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=100"
    },
    {
        id: "app_2",
        title: "Medical Anatomy Hand Diagrams (Coloured)",
        category: "Medical",
        sellerName: "Dr. Shalini",
        sellingPrice: 450.00,
        thumbnail: "https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=100"
    },
    {
        id: "app_3",
        title: "BCA Operating Systems Timelines & CPU Scheduling Notes",
        category: "BCA",
        sellerName: "Rohit CS",
        sellingPrice: 0.00,
        thumbnail: "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=100"
    }
];

let mockPayouts = [
    {
        id: "tx_1",
        sellerName: "Rohan Sharma",
        upiId: "rohan@oksbi",
        amount: 840.00,
        type: "Sale Earnings Withdraw",
        date: "2026-07-08 14:22"
    },
    {
        id: "tx_2",
        sellerName: "Priya Mehta",
        upiId: "priyaGS@okaxis",
        amount: 1540.00,
        type: "Free Reads Visit Bonus",
        date: "2026-07-09 00:10"
    }
];

function renderApprovals() {
    const list = document.getElementById("approvals-list");
    const badge = document.getElementById("approvals-badge");
    badge.innerText = mockApprovals.length;
    
    if (mockApprovals.length === 0) {
        list.innerHTML = `<div class="table-row"><p style="color:#64748B; width:100%; text-align:center; padding: 20px;">No pending approvals.</p></div>`;
        return;
    }

    list.innerHTML = mockApprovals.map(book => `
        <div class="table-row" id="row-${book.id}">
            <img src="${book.thumbnail}" class="book-thumb" alt="Cover">
            <div class="row-details">
                <h4>${book.title}</h4>
                <div class="meta">
                    <span><i class="fa-solid fa-tag"></i> ${book.category}</span>
                    <span><i class="fa-solid fa-user"></i> Uploader: ${book.sellerName}</span>
                </div>
            </div>
            <div class="row-price-badge">${book.sellingPrice > 0 ? `₹${book.sellingPrice.toFixed(2)}` : 'FREE'}</div>
            <div class="row-actions">
                <button class="btn success" onclick="approveResource('${book.id}')"><i class="fa-solid fa-check"></i> Approve</button>
                <button class="btn danger" onclick="rejectResource('${book.id}')"><i class="fa-solid fa-times"></i> Reject</button>
            </div>
        </div>
    `).join("");
}

function renderPayouts() {
    const list = document.getElementById("payouts-list");
    const badge = document.getElementById("payouts-badge");
    badge.innerText = mockPayouts.length;

    if (mockPayouts.length === 0) {
        list.innerHTML = `<div class="table-row"><p style="color:#64748B; width:100%; text-align:center; padding: 20px;">No pending withdrawals.</p></div>`;
        return;
    }

    list.innerHTML = mockPayouts.map(tx => `
        <div class="table-row" id="row-${tx.id}">
            <div class="row-details">
                <h4>₹${tx.amount.toFixed(2)} Withdraw Request</h4>
                <div class="meta">
                    <span><i class="fa-solid fa-user"></i> Creator: ${tx.sellerName}</span>
                    <span><i class="fa-solid fa-wallet"></i> UPI ID: <strong>${tx.upiId}</strong></span>
                    <span><i class="fa-solid fa-calendar"></i> Requested: ${tx.date}</span>
                </div>
            </div>
            <div class="row-actions">
                <button class="btn success" onclick="settlePayout('${tx.id}')"><i class="fa-solid fa-wallet"></i> Mark Settled</button>
                <button class="btn danger" onclick="declinePayout('${tx.id}')"><i class="fa-solid fa-circle-exclamation"></i> Hold</button>
            </div>
        </div>
    `).join("");
}

// ─── ACTION CALLS ───
window.approveResource = function(id) {
    mockApprovals = mockApprovals.filter(b => b.id !== id);
    renderApprovals();
    showNotification("Resource Approved", "The book was listed into the study vault catalog.");
};

window.rejectResource = function(id) {
    const reason = prompt("Enter rejection reason:");
    if (reason === null) return; // Cancelled
    if (reason.trim() === "") {
        alert("Rejection reason is required.");
        return;
    }
    mockApprovals = mockApprovals.filter(b => b.id !== id);
    renderApprovals();
    showNotification("Resource Rejected", `Sent warning note to uploader: "${reason}"`);
};

window.settlePayout = function(id) {
    const txnId = prompt("Enter UPI Transaction Reference ID (UTR):");
    if (txnId === null) return;
    if (txnId.trim() === "") {
        alert("UTR Reference ID is required to complete settlement.");
        return;
    }
    mockPayouts = mockPayouts.filter(t => t.id !== id);
    renderPayouts();
    showNotification("Withdraw Completed", `Sovereign settlement recorded. UTR: ${txnId}`);
};

window.declinePayout = function(id) {
    mockPayouts = mockPayouts.filter(t => t.id !== id);
    renderPayouts();
    showNotification("Withdrawal put on hold", "Creator has been notified to check tax declarations/UPI details.");
};

window.suspendUser = function(userId) {
    if (confirm(`Are you sure you want to suspend account: ${userId} for copyright piracy violation?`)) {
        showNotification("Account Suspended", `Student ID ${userId} has been locked. System triggers sent.`);
    }
};

function showNotification(title, message) {
    if (Notification.permission === "granted") {
        new Notification(title, { body: message });
    } else {
        alert(`${title}: ${message}`);
    }
}

// Request notification access
if (Notification.permission === "default") {
    Notification.requestPermission();
}

// ─── SETTINGS BINDINGS ───
function initSettings() {
    const saveBtn = document.getElementById("save-config-btn");
    saveBtn.addEventListener("click", () => {
        const url = document.getElementById("supabase-url").value;
        const key = document.getElementById("supabase-key").value;
        
        localStorage.setItem("creania_supabase_url", url);
        localStorage.setItem("creania_supabase_key", key);

        alert("Backend settings saved. Direct RLS data channels connected!");
    });

    const url = localStorage.getItem("creania_supabase_url");
    const key = localStorage.getItem("creania_supabase_key");
    if (url) document.getElementById("supabase-url").value = url;
    if (key) document.getElementById("supabase-key").value = key;
}
