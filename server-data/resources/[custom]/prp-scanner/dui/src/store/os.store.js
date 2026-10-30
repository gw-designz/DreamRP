const isDev = process.env.NODE_ENV !== 'production'

const state = {
    isDev,

    currentPage: -1,
    pages: [],
}

if(isDev) {
    state.pages = [
        {
            title: "MTQ_BA2115",
            titleColor: "#00FF42",
            subTitle: "__GROUNDMODE",
            icon: null,
            iconNumber: null,
            iconColor: null,
            bottomText: "CHANGE MODE WITH LMB",
            bottomTextColor: "#00FF62",
            menuItems: [
                {
                    icon: "sun",
                    color: "#F6FF00",
                    title: "SUN: 23"
                },
                {
                    icon: "droplets",
                    color: "#00FFF2",
                    title: "HUMIDITY: 23"
                }
            ]
        },
        {
            title: "MTQ_BA2115",
            titleColor: "#00FF42",
            subTitle: "__FLOWERMODE",
            icon: "growth",
            iconNumber: 1,
            iconColor: "#00FF42",
            bottomText: "CHANGE MODE WITH LMB",
            bottomTextColor: "#00FF62",
            menuItems: [
                {
                    icon: "leaf",
                    color: "#87FF00",
                    title: "GROWTH: 99"
                },
                {
                    icon: "droplet",
                    color: "#00A0FF",
                    title: "WATER: 23"
                },
                {
                    icon: "fertilizer",
                    color: "#3CFF00",
                    title: "FERTIIZER",
                    halfSize: true
                },
                {
                    icon: "death",
                    color: "#19202D",
                    title: "DEATH",
                    halfSize: true,
                    fontColor: "#527EBD",
                }
            ]
        }
    ]
}

const actions = {
    setCurrentPage({commit}, {index}) {
        commit("SET_CURRENT_PAGE", index);
    },
    setPages({commit}, pages) {
        commit("SET_PAGES", pages);
    }
}
const mutations = {
    SET_CURRENT_PAGE(state, index) {
        state.currentPage = index;
    },
    SET_PAGES(state, pages) {
        state.pages = pages;
    }
}
const getters = {}
export default {
    namespaced: true,
    state,
    getters,
    actions,
    mutations,
}