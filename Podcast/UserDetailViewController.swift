//
//  UserDetailViewController.swift
//  Podcast
//
//  Created by Drew Dunne on 3/7/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

final class UserDetailViewController: ViewController {
    
    let episodeCellReuseId = "EpisodeCell"
    let nullEpisodeCellReuseId = "NullEpisodeCell"
    let seriesCellReuseId = "SeriesCell"
    let nullSeriesCellReuseId = "NullSeriesCell"
    
    let headerViewReuseId = "headerViewId"
    
    let recastsHeaderViewTag = 2112
    let subscriptionsHeaderViewTag = 3110
    let navBarHeight: CGFloat = 44
    
    var scrollYOffset: CGFloat = 118
    
    var profileTableView: UITableView!
    var userDetailHeaderView: UserDetailHeaderView!
    var navBar: UserDetailNavigationBar!
    var isLoading: Bool = true
    
    var user: User!
    var subscriptions: [Series] = []
    var recasts: [Episode] = []
    
    var currentlyPlayingIndexPath: IndexPath?
    
    convenience init(user: User) {
        self.init()
        self.user = user
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        profileTableView = UITableView(frame: .zero, style: .grouped)
        profileTableView.register(EpisodeTableViewCell.self, forCellReuseIdentifier: episodeCellReuseId)
        profileTableView.register(NullProfileTableViewCell.self, forCellReuseIdentifier: nullEpisodeCellReuseId)
        profileTableView.register(UserDetailSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: headerViewReuseId)
        profileTableView.delegate = self
        profileTableView.dataSource = self
        profileTableView.backgroundColor = .paleGrey
        profileTableView.rowHeight = UITableViewAutomaticDimension
        profileTableView.separatorStyle = .none
        profileTableView.showsVerticalScrollIndicator = false
        profileTableView.contentInsetAdjustmentBehavior = .never
        profileTableView.contentInset.top = 0
        mainScrollView = profileTableView
        view.addSubview(profileTableView)
        profileTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        userDetailHeaderView = UserDetailHeaderView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: UserDetailHeaderView.minHeight))
        profileTableView.tableHeaderView = userDetailHeaderView
        userDetailHeaderView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(UserDetailHeaderView.minHeight)
            make.width.equalToSuperview()
        }
        userDetailHeaderView.delegate = self
        userDetailHeaderView.subscriptionsHeaderView.delegate = self
        userDetailHeaderView.subscriptionsHeaderView.tag = subscriptionsHeaderViewTag
        userDetailHeaderView.subscriptionsView.register(SeriesGridCollectionViewCell.self, forCellWithReuseIdentifier: seriesCellReuseId)
        userDetailHeaderView.subscriptionsView.register(NullProfileCollectionViewCell.self, forCellWithReuseIdentifier: nullSeriesCellReuseId)
        userDetailHeaderView.subscriptionsView.delegate = self
        userDetailHeaderView.subscriptionsView.dataSource = self
        userDetailHeaderView.setSubscriptions(hidden: isLoading)
        userDetailHeaderView.configure(for: user, isMe: (user.id == System.currentUser!.id)) // Safe unwrap, guaranteed to be there
        
        navBar = UserDetailNavigationBar()
        navBar.configure(for: user)
        navBar.set(shouldHideNavBar: true)
        navigationController?.view.insertSubview(navBar, belowSubview: (navigationController?.navigationBar)!)
        navBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(UIApplication.shared.statusBarFrame.height + navBarHeight)
        }
        
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // updates the constraint to stretch the header view's green background
        let offset = max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
        userDetailHeaderView.contentContainerTop?.update(offset: -offset)
        
        // Animates the header views info for scrolling
        // TODO: Add this animation back in, but not necessary for launch
//        userDetailHeaderView.infoAreaView.animateBy(yOffset: scrollView.contentOffset.y)
        let a = UIApplication.shared.statusBarFrame.height + navBarHeight
        let p = navBar.usernameLabelBottomY
        let h = navBar.usernameLabelHeight
        let y0 = UserDetailHeaderView.infoAreaMinHeight - (userDetailHeaderView.infoAreaView.usernameLabelBottomY + userDetailHeaderView.infoAreaView.usernameLabelHeight)
        let yOffsetThreshold = y0 - (a - p - h)
        let yOffset = scrollView.contentOffset.y
        let aboveThreshold = (yOffset > yOffsetThreshold)
        navBar.set(shouldHideNavBar: !aboveThreshold)
    }
    
    override func stylizeNavBar() {
        navigationController?.navigationBar.tintColor = .offWhite
        navigationController?.navigationBar.setBackgroundImage(UIColor.clear.as1ptImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIColor.clear.as1ptImage()
        navigationController?.navigationBar.backgroundColor = .clear
//        guard let statusBar = UIApplication.shared.value(forKeyPath: "statusBarWindow.statusBar") as? UIView else { return }
//        statusBar.backgroundColor = .clear
    }
    
    override func mainScrollViewSetup() {
        mainScrollView?.contentInsetAdjustmentBehavior = .never
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .lightContent
        stylizeNavBar()
        if (navigationController?.view != navBar.superview) {
            navigationController?.view.insertSubview(navBar, belowSubview: (navigationController?.navigationBar)!)
            navBar.snp.makeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.height.equalTo(UIApplication.shared.statusBarFrame.height + navBarHeight)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchAll()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let navigationBar = navBar {
            navigationBar.removeFromSuperview()
        }
        UIApplication.shared.statusBarStyle = .default
        navigationController?.navigationBar.setBackgroundImage(UIColor.offWhite.as1ptImage(), for: .default)
    }

    override func willMove(toParentViewController parent: UIViewController?) {
        super.willMove(toParentViewController: parent)
        super.stylizeNavBar()
        if let navigationBar = navBar {
            navigationBar.removeFromSuperview()
        }
        navigationController?.navigationBar.setBackgroundImage(UIColor.offWhite.as1ptImage(), for: .default)
    }
    
    func fetchAll() {
        fetchRecasts()
        fetchSubscriptions()
    }
    
    func fetchRecasts() {
        let recastsRequest = FetchUserRecommendationsEndpointRequest(userID: user.id)
        recastsRequest.success = { (endpointRequest: EndpointRequest) in
            guard let results = endpointRequest.processedResponseValue as? [Episode] else { return }
            self.recasts = results
            self.isLoading = false
            self.userDetailHeaderView.setSubscriptions(hidden: self.isLoading)
            self.profileTableView.reloadData()
        }
        recastsRequest.failure = { (endpointRequest: EndpointRequest) in
            // Display error
            print("Could not load user favorites, request failed")
            self.isLoading = false
            self.userDetailHeaderView.setSubscriptions(hidden: self.isLoading)
        }
        System.endpointRequestQueue.addOperation(recastsRequest)
    }
    
    func fetchSubscriptions() {
        let userSubscriptionEndpointRequest = FetchUserSubscriptionsEndpointRequest(userID: user.id)
        userSubscriptionEndpointRequest.success = { (endpointRequest: EndpointRequest) in
            guard let subscriptions = endpointRequest.processedResponseValue as? [Series] else { return }
            self.subscriptions = subscriptions.sorted { $0.numberOfSubscribers > $1.numberOfSubscribers }
            self.userDetailHeaderView.subscriptionsView.reloadData()
            self.userDetailHeaderView.remakeSubscriptionsViewContraints()
            self.userDetailHeaderView.subscriptionsHeaderView.browseButton.isHidden = subscriptions.count == 0 // so we don't go to null state
        }
        userSubscriptionEndpointRequest.failure = { (endpointRequest: EndpointRequest) in
            // Should probably do something here
            self.userDetailHeaderView.remakeSubscriptionsViewContraints()
        }
        System.endpointRequestQueue.addOperation(userSubscriptionEndpointRequest)
    }

}

//
// MARK: UITableViewDelegate & UITableViewDataSource
//
extension UserDetailViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isLoading ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recasts.count == 0 ? 1 : recasts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if recasts.count != 0 {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: episodeCellReuseId) as? EpisodeTableViewCell else { return EpisodeTableViewCell() }
            let episode = recasts[indexPath.row]
            cell.delegate = self
            cell.setup(with: episode, and: EpisodeManager.consolidateInfo(for: episode))
            cell.layoutSubviews()
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: nullEpisodeCellReuseId) as? NullProfileTableViewCell else { return NullProfileTableViewCell(style: .default, reuseIdentifier: nullEpisodeCellReuseId) }
            cell.setup(for: user, isMe: (System.currentUser!.id == user.id))
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UserDetailSectionHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerViewReuseId) as? UserDetailSectionHeaderView {
            header.configure(for: .recasts, and: user, isMe: (System.currentUser!.id == user.id))
            header.delegate = self
            header.tag = recastsHeaderViewTag
            return header
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if recasts.count > 0 {
            return UITableViewAutomaticDimension
        } else if user == System.currentUser! {
            return NullProfileTableViewCell.heightForCurrentUser
        } else {
            return NullProfileTableViewCell.heightForUser
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if recasts.count > 0 {
            let episode = recasts[indexPath.row]
            let episodeDetailViewController = EpisodeDetailViewController()
            episodeDetailViewController.episode = episode
            navigationController?.pushViewController(episodeDetailViewController, animated: true)
        } else {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let tabBarController = appDelegate.tabBarController else { return }
            tabBarController.programmaticallyPressTabBarButton(atIndex: System.discoverTab)
        }
    }
    
}
    
//
// MARK: UICollectionViewDelegate & UICollectionViewDataSource
//
extension UserDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return subscriptions.count == 0 ? 1 : subscriptions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if subscriptions.count > 0 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: seriesCellReuseId, for: indexPath) as? SeriesGridCollectionViewCell else { return SeriesGridCollectionViewCell() }
            let series = subscriptions[indexPath.item]
            cell.configureForSeries(series: series)
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: nullSeriesCellReuseId, for: indexPath) as? NullProfileCollectionViewCell else { return NullProfileCollectionViewCell() }
            cell.setup(for: user, isMe: (System.currentUser!.id == user.id))
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if subscriptions.count > 0 {
            return CGSize(width: RecommendedSeriesCollectionViewFlowLayout.widthHeight, height: collectionView.frame.height)
        } else if System.currentUser! == user {
            return CGSize(width: collectionView.frame.height, height: collectionView.frame.height);
        } else {
            return CGSize(width: collectionView.frame.width, height: NullProfileCollectionViewCell.heightForUser);
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if subscriptions.count > 0 {
            let seriesDetailViewController = SeriesDetailViewController(series: subscriptions[indexPath.row])
            navigationController?.pushViewController(seriesDetailViewController, animated: true)
        } else {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let tabBarController = appDelegate.tabBarController else { return }
            tabBarController.programmaticallyPressTabBarButton(atIndex: System.discoverTab)
        }
    }
    
}

//
// MARK: UserDetailSectionHeaderViewDelegate
//
extension UserDetailViewController: UserDetailSectionHeaderViewDelegate {
    func userDetailSectionViewHeaderDidPressSeeAll(header: UserDetailSectionHeaderView) {
        switch header.tag {
        case subscriptionsHeaderViewTag:
            let vc = SubscriptionsViewController(user: user)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
}
    
//
// MARK: EpisodeTableViewCellDelegate
//
extension UserDetailViewController: EpisodeTableViewCellDelegate {

    func episodeTableViewCellDidPressPlayPauseButton(episodeTableViewCell: EpisodeTableViewCell) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let indexPath = profileTableView.indexPath(for: episodeTableViewCell) else { return }
        let episode = recasts[indexPath.row]
        appDelegate.showAndExpandPlayer()
        Player.sharedInstance.playEpisode(episode: episode)
        episodeTableViewCell.updateWithPlayButtonPress(episode: episode)
        
        // reset previously playings view
        if let playingIndexPath = currentlyPlayingIndexPath, currentlyPlayingIndexPath != indexPath, let currentlyPlayingCell = profileTableView.cellForRow(at: playingIndexPath) as? EpisodeTableViewCell {
            let playingEpisode = recasts[playingIndexPath.row]
            currentlyPlayingCell.updateWithPlayButtonPress(episode: playingEpisode)
        }
        
        // update index path
        currentlyPlayingIndexPath = indexPath
    }
    
    func episodeTableViewCellDidPressRecommendButton(episodeTableViewCell: EpisodeTableViewCell) {
        guard let indexPath = profileTableView.indexPath(for: episodeTableViewCell) else { return }
        let episode = recasts[indexPath.row]
        episode.recommendedChange(completion: episodeTableViewCell.setRecommendedButtonToState)
    }
    
    func episodeTableViewCellDidPressBookmarkButton(episodeTableViewCell: EpisodeTableViewCell) {
        guard let indexPath = profileTableView.indexPath(for: episodeTableViewCell) else { return }
        let episode = recasts[indexPath.row]
        episode.bookmarkChange(completion: episodeTableViewCell.setBookmarkButtonToState)
    }
    
    func episodeTableViewCellDidPressMoreActionsButton(episodeTableViewCell: EpisodeTableViewCell) {
        guard let indexPath = profileTableView.indexPath(for: episodeTableViewCell) else { return }
        let episode = recasts[indexPath.row]
        let option1 = ActionSheetOption(type: .download(selected: episode.isDownloaded), action: {
            DownloadManager.shared.downloadOrRemove(episode: episode, callback: self.didReceiveDownloadUpdateFor)
        })
        let shareEpisodeOption = ActionSheetOption(type: .shareEpisode, action: {
            guard let user = System.currentUser else { return }
            let viewController = ShareEpisodeViewController(user: user, episode: episode)
            self.navigationController?.pushViewController(viewController, animated: true)
        })
        
        var header: ActionSheetHeader?
        
        if let image = episodeTableViewCell.episodeSubjectView.podcastImage.image, let title = episodeTableViewCell.episodeSubjectView.episodeNameLabel.text, let description = episodeTableViewCell.episodeSubjectView.dateTimeLabel.text {
            header = ActionSheetHeader(image: image, title: title, description: description)
        }
        
        let actionSheetViewController = ActionSheetViewController(options: [option1, shareEpisodeOption], header: header)
        showActionSheetViewController(actionSheetViewController: actionSheetViewController)
    }
    
}

//
// MARK: UserDetailHeaderViewDelegate
//
extension UserDetailViewController: UserDetailHeaderViewDelegate {
    func userDetailHeaderDidPressFollowButton(header: UserDetailHeaderView) {
        userDetailHeaderView.infoAreaView.followButton.isEnabled = false // Disable so user cannot send multiple requests
        userDetailHeaderView.infoAreaView.followButton.setTitleColor(.offBlack, for: .disabled)
        let completion: ((Bool, Int) -> ()) = { (isFollowing, _) in
            self.userDetailHeaderView.infoAreaView.followButton.isEnabled = true
            self.userDetailHeaderView.infoAreaView.followButton.isSelected = isFollowing
            self.userDetailHeaderView.buttonBar.configure(for: self.user)
        }
        user.followChange(completion: completion)
    }
    
    func userDetailHeaderDidPressFollowers(header: UserDetailHeaderView) {
        let followersViewController = FollowerFollowingViewController(user: user)
        followersViewController.followersOrFollowings = .Followers
        navigationController?.pushViewController(followersViewController, animated: true)
    }
    
    func userDetailHeaderDidPressFollowing(header: UserDetailHeaderView) {
        let followingViewController = FollowerFollowingViewController(user: user)
        followingViewController.followersOrFollowings = .Followings
        navigationController?.pushViewController(followingViewController, animated: true)
    }
    
    
}
    
//
// MARK: EpisodeDownloader
//
extension UserDetailViewController: EpisodeDownloader {
    func didReceiveDownloadUpdateFor(episode: Episode) {
        if let row = recasts.index(of: episode) {
            profileTableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        }
    }
}
