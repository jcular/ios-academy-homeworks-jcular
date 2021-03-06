//
//  ShowDetailsViewController.swift
//  TVShows
//
//  Created by Jure Cular on 24/07/2018.
//  Copyright © 2018 Jure Čular. All rights reserved.
//

import UIKit
import PromiseKit

class ShowDetailsViewController: UIViewController {

    // MARK: - IBOutlets -

    @IBOutlet private weak var _addButton: UIButton!
    @IBOutlet private weak var _addButtonBottomConstraints: NSLayoutConstraint!
    @IBOutlet private weak var _tableView: UITableView! {
        didSet {
            _tableView.delegate = self
            _tableView.dataSource = self

            _tableView.rowHeight = UITableViewAutomaticDimension
            _tableView.estimatedRowHeight = 300
            _tableView.contentInset.bottom = _addButton.frame.size.height + _addButtonBottomConstraints.constant

            _tableView.refreshControl = _refreshControl
            _refreshControl.tintColor = UIColor.ts.pink
            _refreshControl.addTarget(self, action: #selector(_refreashData), for: .valueChanged)
        }
    }
    
    // MARK: - Private properties -

    private var _token: String!
    private var _showID: String!
    private var _showDetails: ShowDetails?
    private var _episodes: [Episode] = []

    private let _refreshControl = UIRefreshControl()
    
    // MARK: - Init -

    public class func initFromStoryboard(withToken token: String, showID: String) -> ShowDetailsViewController {
        let showDetailsStoryboard = UIStoryboard(name: "ShowDetails", bundle: nil)
        let showDetailsViewController = showDetailsStoryboard.instantiateInitialViewController() as! ShowDetailsViewController
        showDetailsViewController._token = token
        showDetailsViewController._showID = showID

        return showDetailsViewController
    }

    // MARK: - Lifeciycle -

    override func viewDidLoad() {
        super.viewDidLoad()
        _loadShowData(withToken: _token, showID: _showID)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - IBActions -

    @IBAction private func _didTapBackButton(_ sender: Any) {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.popViewController(animated: true)
    }

    @IBAction private func _didTapAddEpisode(_ sender: Any) {
        let addEpisodeViewController = AddEpisodeViewController.initFromStoryboard(withToken: _token, showID: _showID)
        addEpisodeViewController.delegate = self

        let navigationController = UINavigationController.init(rootViewController: addEpisodeViewController)

        present(navigationController, animated: true, completion: nil)
    }

}

extension ShowDetailsViewController: Progressable, Alertable {

    // MARK: - Data loading -

    @objc private func _refreashData() {
        _loadShowData(withToken: _token, showID: _showID)
    }

    private func _loadShowData(withToken token: String, showID: String) {
        showProgressView()

        firstly {
            APIManager.getShowDetails(withToken: token, showID: showID)
        }.then { [weak self] (showDetails: ShowDetails) -> Promise<[Episode]> in
            self?._showDetails = showDetails
            return APIManager.getShowEpisodes(withToken: token, showID: showID)
        }.done { [weak self] (episodes: [Episode]) in
            guard let `self` = self else { return }
            self._episodes = episodes
            self._tableView.reloadData()
            if self._refreshControl.isRefreshing {
                self._refreshControl.endRefreshing()
            }
        }.catch { [weak self] error in
            self?.showAlertView(title: "Failed to fetch show details",
                                message: "Failed to fetch show details, please check your internet connection.")
        }.finally{ [weak self] in
            self?.hideProgress()
        }
    }

}

// MARK: - UITableViewDelegate -

extension ShowDetailsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row > 1 else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)

        let episode = _episodes[indexPath.row - 2]
        let episodeDetailsViewController = EpisodeDetailsViewController.initFromStoryboard(withToken: _token, episodeID: episode.id)
        navigationController?.show(episodeDetailsViewController, sender: self)
    }

}

// MARK: - UITableViewDataSource -

extension ShowDetailsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.row > 1 else {
            return []
        }
        let deleteButton = UITableViewRowAction(style: .default, title: "Delete") { [weak self] (action, indexPath) in
            self?._episodes.remove(at: indexPath.row - 2)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        return [deleteButton]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _episodes.count + 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "ShowImageTableViewCell",
                    for: indexPath
                    ) as! ShowImageTableViewCell
                if let showDetails = _showDetails {
                    cell.configure(imageResource: showDetails.imageURL)
                }
                cell.selectionStyle = .none
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "ShowDescriptionTableViewCell",
                    for: indexPath
                ) as! ShowDescriptionTableViewCell
                if let showDetails = _showDetails {
                    cell.configure(showDetails: showDetails, episodesNumber: _episodes.count)
                }

                cell.selectionStyle = .none
                return cell
            default:
                let cell = tableView.dequeueReusableCell(
                    withIdentifier: "EpisodeTableViewCell",
                    for: indexPath
                ) as! EpisodeTableViewCell
                cell.configure(episode: _episodes[indexPath.row - 2])

                return cell
        }
    }

}


// MARK: - AddEpisodeViewControllerDelegate -

extension ShowDetailsViewController: AddEpisodeViewControllerDelegate {

    func succesfullyAddedEpisode() {
        _loadShowData(withToken: _token, showID: _showID)
    }

}
