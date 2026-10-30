import{d as r,u as t,r as e,j as i,fR as s}from"./vendor-8f9a1d00.js";import{u as a,R as o}from"./index-e43e59d9.js";const l=r.div.attrs({className:"tgg-banking-history-tab"})`
	display: flex;
	flex-direction: column;
	padding: 0 1.5rem;
	height: 100%;
	overflow: hidden;
	font-family: Manrope, sans-serif;
	background-color: ${r=>r.$isDark?"#101922":"#f8fafc"};
	color: ${r=>r.$isDark?"#fff":"#1e293b"};

	.tgg-history-search-wrapper {
		position: relative;
		margin: 1rem 0 0.75rem 0;
		flex-shrink: 0;
	}

	.tgg-history-search-icon {
		position: absolute;
		left: 0.625rem;
		top: 50%;
		transform: translateY(-50%);
		color: ${r=>r.$isDark?"#9ca3af":"#64748b"};
		pointer-events: none;
		font-size: calc(1rem * ${r=>r.$resizeBy});
	}

	.tgg-history-search-input {
		width: 100%;
		padding: 0.4375rem 0.625rem 0.4375rem 2rem;
		border: none;
		border-radius: 0.625rem;
		font-size: calc(0.75rem * ${r=>r.$resizeBy});
		background: ${r=>r.$isDark?"rgba(255, 255, 255, 0.05)":"#fff"};
		color: ${r=>r.$isDark?"#fff":"#1e293b"};
		border: 1px solid
			${r=>r.$isDark?"rgba(255, 255, 255, 0.1)":"rgba(0, 0, 0, 0.08)"};
		backdrop-filter: blur(10px);
		-webkit-backdrop-filter: blur(10px);

		&::placeholder {
			color: ${r=>r.$isDark?"#9ca3af":"#64748b"};
		}

		&:focus {
			outline: none;
			box-shadow: 0 0 0 2px rgba(19, 127, 236, 0.5);
		}
	}

	.tgg-history-filters-row {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		margin-bottom: 0.75rem;
		flex-shrink: 0;
	}

	.tgg-history-title {
		font-size: calc(0.9375rem * ${r=>r.$resizeBy});
		font-weight: 700;
		color: ${r=>r.$isDark?"#f9fafb":"#1e293b"};
		margin: 0;
	}

	.tgg-history-filter-pills {
		display: flex;
		gap: 0.375rem;
	}

	.tgg-history-filter-btn {
		font-size: calc(0.6875rem * ${r=>r.$resizeBy});
		font-weight: 600;
		padding: 0.1875rem 0.625rem;
		border-radius: 9999px;
		border: none;
		cursor: pointer;
		background: transparent;
		color: ${r=>r.$isDark?"#9ca3af":"#64748b"};
		transition: background 0.2s, color 0.2s;
	}

	.tgg-history-filter-btn:hover {
		background: ${r=>r.$isDark?"rgba(255,255,255,0.08)":"rgba(0,0,0,0.04)"};
	}

	.tgg-history-filter-btn.tgg-history-filter-active {
		background: #137fec;
		color: #fff;
	}

	.tgg-history-filter-btn.tgg-history-filter-active:hover {
		background: #137fec;
	}

	.tgg-history-content {
		flex: 1;
		min-height: 0;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}
`,n=({onTransactionClick:r,toolbarHeight:n=0})=>{const{t:c}=t(),[g,f]=e.useState(""),[h,d]=e.useState("all"),y=a(r=>r.resizeBy),b=a(r=>r.settings),m="dark"===(null==b?void 0:b.theme);return i.jsxs(l,{$resizeBy:y,$isDark:m,children:[i.jsxs("div",{className:"tgg-history-search-wrapper",children:[i.jsx("span",{className:"tgg-history-search-icon",children:i.jsx(s,{size:18})}),i.jsx("input",{className:"tgg-history-search-input",type:"text",placeholder:c("ypay.searchByNameOrNumber","Search by name or number..."),value:g,onChange:r=>f(r.target.value)})]}),i.jsxs("div",{className:"tgg-history-filters-row",children:[i.jsx("h3",{className:"tgg-history-title",children:c("ypay.allTransactions","All Transactions")}),i.jsxs("div",{className:"tgg-history-filter-pills",children:[i.jsx("button",{type:"button",className:"tgg-history-filter-btn "+("all"===h?"tgg-history-filter-active":""),onClick:()=>d("all"),children:c("ypay.filterAll","All")}),i.jsx("button",{type:"button",className:"tgg-history-filter-btn "+("in"===h?"tgg-history-filter-active":""),onClick:()=>d("in"),children:c("ypay.filterIn","In")}),i.jsx("button",{type:"button",className:"tgg-history-filter-btn "+("out"===h?"tgg-history-filter-active":""),onClick:()=>d("out"),children:c("ypay.filterOut","Out")})]})]}),i.jsx("div",{className:"tgg-history-content",children:i.jsx(o,{limit:999,onSeeAll:void 0,onTransactionClick:r,isDark:m,compact:!0,toolbarHeight:n,scrollContainerId:"tgg-ypay-history-transactions-scroll",searchQuery:g,filterMode:h,useContactInitials:!0,hideHeader:!0})})]})};export{n as HistoryTab};
